import Foundation
import Network

public class Connection {
  let host: String
  var onDisconnected: (Error) -> Void

  private let connection: NWConnection
  private var buffer = Data()

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
    onDisconnected = { _ in }
  }

  public init(host: String, port: Int) {
    self.host = host
    let endpoint = NWEndpoint.hostPort(
      host: NWEndpoint.Host(host),
      port: NWEndpoint.Port(rawValue: UInt16(port))!
    )
    connection = NWConnection(to: endpoint, using: .tcp)
    onDisconnected = { _ in }
  }

  public func connect() async throws {
    return try await withCheckedThrowingContinuation { (continuation) in
      connection.stateUpdateHandler = { (state) in
        switch state {
        case .setup, .preparing:
          break
        case .waiting(let error):
          continuation.resume(throwing: error)
          self.connection.stateUpdateHandler = nil
        case .ready:
          continuation.resume()
          self.connection.stateUpdateHandler = stateUpdateHandler
        case .failed(let error):
          continuation.resume(throwing: error)
          self.connection.stateUpdateHandler = nil
        case .cancelled:
          continuation.resume(throwing: ConnectionError.cancelled)
          self.connection.stateUpdateHandler = nil
        @unknown default:
          break
        }
      }

      connection.start(queue: .global(qos: .userInitiated))
    }

    @Sendable
    func stateUpdateHandler(_ state: NWConnection.State) {
      switch state {
      case .waiting(let error), .failed(let error):
        onDisconnected(error)
      case .setup, .preparing, .ready, .cancelled:
        break
      @unknown default:
        break
      }
    }
  }

  public func disconnect() {
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
    let minimumIncompleteLength = 0
    let maximumLength = 65536

    connection.receive(
      minimumIncompleteLength: minimumIncompleteLength,
      maximumLength: maximumLength)
    { (content, contentContext, isComplete, error) in
      if let error = error {
        completion(.failure(error))
        return
      }

      guard let content else {
        if isComplete {
          completion(.failure(ConnectionError.disconnected))
        } else {
          completion(.failure(ConnectionError.noData))
        }
        return
      }

      let transportPacket = DirectTCPPacket(response: content)
      let length = Int(transportPacket.protocolLength)

      self.buffer.append(Data(transportPacket.smb2Message))

      self.receive(upTo: length) { (result) in
        switch result {
        case .success:
          let data = Data(self.buffer.prefix(length))
          self.buffer = Data(self.buffer.suffix(from: length))

          let reader = ByteReader(data)
          var offset = 0

          var header: Header
          var response = Data()
          repeat {
            header = reader.read()

            switch NTStatus(header.status) {
            case
              .success,
              .moreProcessingRequired,
              .noMoreFiles,
              .endOfFile:
              response += data
            case .pending:
              if self.buffer.count > 0 {
                let transportPacket = DirectTCPPacket(response: self.buffer)
                let length = Int(transportPacket.protocolLength)

                if self.buffer.count < length {
                  self.receive(completion: completion)
                  return
                }

                let data = transportPacket.smb2Message
                self.buffer = Data(self.buffer.suffix(from: 4 + length))

                let reader = ByteReader(data)
                let header: Header = reader.read()

                switch NTStatus(header.status) {
                case
                  .success,
                  .moreProcessingRequired,
                  .noMoreFiles,
                  .endOfFile:
                  response += data
                  break
                default:
                  completion(.failure(ErrorResponse(data: data)))
                  return
                }
              } else {
                self.receive(completion: completion)
                return
              }
            default:
              completion(.failure(ErrorResponse(data: Data(data[offset...]))))
              return
            }

            offset += Int(header.nextCommand)
            reader.seek(to: offset)
          } while header.nextCommand > 0

          completion(.success(response))
        case .failure(let error):
          completion(.failure(error))
        }
      }
    }
  }

  private func receive(upTo byteCount: Int, completion: @escaping (Result<(), Error>) -> Void) {
    let minimumIncompleteLength = 0
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
            completion(.failure(ConnectionError.noData))
          }
          return
        }

        self.buffer.append(data)
        self.receive(upTo: byteCount, completion: completion)
      }
      return
    }

    completion(.success(()))
  }
}

public enum ConnectionError: Error {
  case noData
  case disconnected
  case cancelled
  case unknown
}
