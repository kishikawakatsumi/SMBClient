import Foundation
import Network

public class Connection {
  let host: String
  var onDisconnected: (Error) -> Void

  private let connection: NWConnection
  private let queue: DispatchQueue
  private var buffer = Data()

  // Set by Session once SMB3 encryption keys are derived. When a received
  // message begins with the TRANSFORM_HEADER protocolId, it is decrypted to the
  // underlying SMB2 message before any header parsing.
  //
  // Written via `setDecryptor` (which hops onto `queue`) and only ever read in
  // `decryptIfNeeded`, which runs inside the NWConnection receive callback on
  // `queue`. Keeping both on the serial `queue` gives a clean happens-before so
  // there is no data race on this field across the async executor / connection
  // queue boundary.
  private var decryptor: ((Data) throws -> Data)?

  /// Install (or clear) the decrypt hook. Routed through the connection's serial
  /// `queue` so it is ordered with the receive-path reads of `decryptor`. Called
  /// from Session's async context (never from `queue`), so `sync` can't deadlock.
  func setDecryptor(_ decryptor: ((Data) throws -> Data)?) {
    queue.sync { self.decryptor = decryptor }
  }

  private let semaphore = Semaphore(value: 1)

  public var state: NWConnection.State {
    connection.state
  }

  public init(host: String) {
    self.host = host
    
    let endpoint = NWEndpoint.hostPort(
      host: NWEndpoint.Host(host),
      port: NWEndpoint.Port(integerLiteral: 445)
    )
    connection = NWConnection(to: endpoint, using: .tcp)
    queue = DispatchQueue(label: "com.kishikawakatsumi.smbclient.connection.\(host):445", qos: .userInitiated)
    onDisconnected = { _ in }
  }

  public init(host: String, port: Int) {
    self.host = host
    let endpoint = NWEndpoint.hostPort(
      host: NWEndpoint.Host(host),
      port: NWEndpoint.Port(rawValue: UInt16(port))!
    )
    connection = NWConnection(to: endpoint, using: .tcp)
    queue = DispatchQueue(label: "com.kishikawakatsumi.smbclient.connection.\(host):\(port)", qos: .userInitiated)
    onDisconnected = { _ in }
  }

  public func connect() async throws {
    return try await withCheckedThrowingContinuation { continuation in
      let handler = ConnectionStateHandler(
        completion: { continuation.resume(with: $0) },
        onDisconnected: { [weak self] in self?.onDisconnected($0) }
      )
      connection.stateUpdateHandler = handler.handle
      connection.start(queue: queue)
    }
  }

  public func disconnect() {
    // Do not nil stateUpdateHandler before cancelling: NWConnection delivers
    // the .cancelled state update asynchronously, and clearing the handler
    // first would prevent any in-flight connect() continuation from being
    // resumed, causing a hang. The retain cycle is instead broken by
    // capturing self weakly in the handler closures.
    connection.cancel()
  }

  public func send(_ data: Data) async throws -> Data {
    await semaphore.wait()
    defer { Task { await semaphore.signal() } }

    switch connection.state {
    case .setup:
      try await connect()
    case .waiting(let error), .failed(let error):
      onDisconnected(error)
      throw error
    case .preparing, .ready:
      break
    case .cancelled:
      throw ConnectionError.cancelled
    @unknown default:
      throw ConnectionError.unknown
    }

    let transportPacket = DirectTCPPacket(smb2Message: data)
    let content = transportPacket.encoded()

    return try await withCheckedThrowingContinuation { (continuation) in
      connection.send(content: content, completion: .contentProcessed() { (error) in
        if let error {
          continuation.resume(throwing: error)
          return
        }

        self.receive() { (result) in
          switch result {
          case .success(let data):
            continuation.resume(returning: data)
          case .failure(let error):
            continuation.resume(throwing: error)
          }
        }
      })
    }
  }

  private func receive(completion: @escaping (Result<Data, Error>) -> Void) {
    receive(upTo: 4) { result in
      if case .failure(let error) = result {
        completion(.failure(error))
        return
      }
      let transportPacket = DirectTCPPacket(response: self.buffer)
      let length = Int(transportPacket.protocolLength)
      guard self.buffer.first == 0, length >= 64 else {
        self.disconnect()
        completion(.failure(ConnectionError.invalidResponse))
        return
      }
      self.buffer = Data(transportPacket.smb2Message)
      self.receive(upTo: length) { result in
        switch result {
        case .failure(let error):
          completion(.failure(error))
        case .success:
          let packet = Data(self.buffer.prefix(length))
          self.buffer = Data(self.buffer.dropFirst(length))
          do {
            let data = try self.decryptIfNeeded(packet)
            if try Self.isCompleteResponse(data) {
              completion(.success(data))
            } else {
              // Drain already-buffered frames too, without recursively growing the stack.
              self.queue.async { self.receive(completion: completion) }
            }
          } catch {
            if error is ConnectionError { self.disconnect() }
            completion(.failure(error))
          }
        }
      }
    }
  }

  /// Validate the envelope before any unchecked Header or ErrorResponse decoding.
  static func isCompleteResponse(_ data: Data) throws -> Bool {
    let bytes = Data(data)
    var offset = 0
    while true {
      let remaining = bytes.count - offset
      guard remaining >= 64 else { throw ConnectionError.invalidResponse }
      let header = Header(data: Data(bytes[offset..<(offset + 64)]))
      guard header.protocolId == 0x424D53FE, header.structureSize == 64 else {
        throw ConnectionError.invalidResponse
      }
      let next = Int(header.nextCommand)
      guard next == 0 || (next >= 64 && next.isMultiple(of: 8) && next <= remaining - 64) else {
        throw ConnectionError.invalidResponse
      }
      switch NTStatus(header.status) {
      case .success, .moreProcessingRequired, .noMoreFiles, .endOfFile:
        break
      case .pending:
        guard offset == 0, next == 0 else { throw ConnectionError.invalidResponse }
        return false
      default:
        let commandLength = next == 0 ? remaining : next
        guard commandLength >= 68 else { throw ConnectionError.invalidResponse }
        throw ErrorResponse(data: Data(bytes[offset..<(offset + commandLength)]))
      }
      if next == 0 { return true }
      offset += next
    }
  }

  private func decryptIfNeeded(_ data: Data) throws -> Data {
    guard data.count >= 4, let decryptor else { return data }
    // TRANSFORM_HEADER protocolId 0x424D53FD on the wire is bytes FD 53 4D 42.
    if data[data.startIndex] == 0xFD,
       data[data.startIndex + 1] == 0x53,
       data[data.startIndex + 2] == 0x4D,
       data[data.startIndex + 3] == 0x42 {
      return try decryptor(data)
    }
    return data
  }

  private func receive(upTo byteCount: Int, completion: @escaping (Result<(), Error>) -> Void) {
    let minimumIncompleteLength = 1
    let maximumLength = 65536

    if self.buffer.count < byteCount {
      self.connection.receive(minimumIncompleteLength: minimumIncompleteLength, maximumLength: maximumLength) { (data, _, isComplete, error) in
        if let error = error {
          completion(.failure(error))
          return
        }

        guard let data else {
          if isComplete {
            completion(.failure(ConnectionError.disconnected))
          } else {
            self.receive(upTo: byteCount, completion: completion)
          }
          return
        }

        self.buffer.append(data)
        if isComplete && self.buffer.count < byteCount {
          completion(.failure(ConnectionError.disconnected))
          return
        }
        self.receive(upTo: byteCount, completion: completion)
      }
      return
    }

    completion(.success(()))
  }
}

/// Replacing NWConnection's callback cannot revoke callbacks already enqueued.
/// Consume connection completion before resuming its continuation instead.
final class ConnectionStateHandler {
  private let lock = NSLock()
  private var completion: ((Result<Void, Error>) -> Void)?
  private var established = false
  private let onDisconnected: (Error) -> Void

  init(
    completion: @escaping (Result<Void, Error>) -> Void,
    onDisconnected: @escaping (Error) -> Void
  ) {
    self.completion = completion
    self.onDisconnected = onDisconnected
  }

  func handle(_ state: NWConnection.State) {
    let result: Result<Void, Error>
    let disconnection: Error?
    switch state {
    case .ready:
      result = .success(())
      disconnection = nil
    case .waiting(let error), .failed(let error):
      result = .failure(error)
      disconnection = error
    case .cancelled:
      result = .failure(ConnectionError.cancelled)
      disconnection = nil
    case .setup, .preparing:
      return
    @unknown default:
      return
    }

    lock.lock()
    let completion = self.completion
    self.completion = nil
    if completion != nil, case .success = result { established = true }
    let notifyDisconnection = completion == nil && established
    lock.unlock()

    if let completion {
      completion(result)
    } else if notifyDisconnection, let disconnection {
      onDisconnected(disconnection)
    }
  }
}

public enum ConnectionError: Error {
  case disconnected
  case cancelled
  case unknown
  case invalidResponse
}
