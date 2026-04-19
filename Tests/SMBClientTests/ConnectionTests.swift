import XCTest
import Network
@testable import SMBClient

final class ConnectionTests: XCTestCase {
  /// Returns a 64-byte encoded SMB2 header with the given status patched in.
  private func smb2Message(status: UInt32) -> Data {
    var data = Header(command: .echo, messageId: 0, sessionId: 0).encoded()
    // Status field is at byte offset 8–11 (little-endian)
    data[8]  = UInt8((status      ) & 0xFF)
    data[9]  = UInt8((status >>  8) & 0xFF)
    data[10] = UInt8((status >> 16) & 0xFF)
    data[11] = UInt8((status >> 24) & 0xFF)
    return data
  }

  // MARK: - Mock server helpers

  /// Script describing how the mock server should respond to the first received request.
  /// Each fragment is sent as a separate `serverConn.send(...)` with a small delay
  /// between them so the client observes them as distinct receives.
  private struct ServerScript {
    let fragments: [Data]
    /// Delay in seconds between fragment sends. Needs to be large enough for TCP
    /// to deliver them as separate segments on loopback.
    var interFragmentDelaySeconds: Double = 0.05
  }

  /// Starts a local loopback TCP listener, waits for the first incoming connection,
  /// then plays back `script.fragments` with delays. Returns the listener and the
  /// OS-assigned port once it's ready.
  private func startMockServer(
    script: ServerScript,
    serverDone: XCTestExpectation?
  ) async throws -> (NWListener, UInt16) {
    let listenerQueue = DispatchQueue(label: "test.mock.server")
    // Disable Nagle so that close-in-time sends are not coalesced into one segment.
    let tcpOptions = NWProtocolTCP.Options()
    tcpOptions.noDelay = true
    let params = NWParameters(tls: nil, tcp: tcpOptions)
    let listener = try NWListener(using: params, on: .any)

    listener.newConnectionHandler = { serverConn in
      serverConn.start(queue: listenerQueue)
      // Consume (and ignore) any data the client sends.
      func drainLoop() {
        serverConn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { _, _, isComplete, _ in
          if !isComplete { drainLoop() }
        }
      }
      drainLoop()

      // Send each scripted fragment sequentially, with a delay between them.
      func sendNext(_ index: Int) {
        guard index < script.fragments.count else {
          serverDone?.fulfill()
          return
        }
        serverConn.send(content: script.fragments[index], completion: .contentProcessed { _ in
          if index + 1 < script.fragments.count {
            listenerQueue.asyncAfter(deadline: .now() + script.interFragmentDelaySeconds) {
              sendNext(index + 1)
            }
          } else {
            serverDone?.fulfill()
          }
        })
      }
      sendNext(0)
    }

    let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
      let resumed = ResumeLatch()
      listener.stateUpdateHandler = { state in
        switch state {
        case .ready:
          guard resumed.trip() else { return }
          continuation.resume(returning: listener.port!.rawValue)
        case .failed(let error):
          guard resumed.trip() else { return }
          continuation.resume(throwing: error)
        default:
          break
        }
      }
      listener.start(queue: listenerQueue)
    }
    return (listener, port)
  }

  /// Tiny helper that lets a stateUpdateHandler resume a continuation exactly once
  /// even though it may be invoked multiple times.
  private final class ResumeLatch: @unchecked Sendable {
    private let lock = NSLock()
    private var done = false
    func trip() -> Bool {
      lock.lock(); defer { lock.unlock() }
      if done { return false }
      done = true
      return true
    }
  }

  // MARK: - Existing test: off-by-4 boundary (PR #217)

  /// Reproduces the off-by-4 bug in `Connection.receive(completion:)`.
  ///
  /// When a STATUS_PENDING response arrives and `self.buffer` already contains the
  /// 4-byte DirectTCP header **plus some but not all** bytes of the follow-up SUCCESS
  /// message, the guard condition must check `self.buffer.count < 4 + length`.
  /// The old, buggy guard `self.buffer.count < length` would skip waiting for
  /// the missing bytes and try to parse a truncated packet.
  func testPendingFollowedBySuccessWithFragmentedTCPDelivery() async throws {
    let pendingSmb2 = smb2Message(status: 0x00000103)
    let successSmb2 = smb2Message(status: 0x00000000)
    let pendingFrame = DirectTCPPacket(smb2Message: pendingSmb2).encoded()
    let successFrame = DirectTCPPacket(smb2Message: successSmb2).encoded()

    let fragment1 = pendingFrame + successFrame.prefix(successFrame.count - 1)
    let fragment2 = successFrame.suffix(1)

    let serverDone = XCTestExpectation(description: "server finished sending both fragments")
    let (listener, port) = try await startMockServer(
      script: ServerScript(fragments: [Data(fragment1), Data(fragment2)]),
      serverDone: serverDone
    )
    defer { listener.cancel() }

    let connection = Connection(host: "127.0.0.1", port: Int(port))
    defer { connection.disconnect() }

    let responseData = try await connection.send(successSmb2)

    await fulfillment(of: [serverDone], timeout: 5)

    XCTAssertEqual(responseData.count, successSmb2.count)
    XCTAssertTrue(NTStatus(Header(data: responseData).status) == ErrorCode.success)
  }

  // MARK: - #1, #2: DirectTCP header fragmented across receives (PR #219)

  /// Server sends the 4-byte DirectTCP header in two pieces (2 + 2 bytes),
  /// then the SMB2 body. The fix (`receive(upTo: 4)`) must buffer until the
  /// full header arrives; the old code constructed DirectTCPPacket with fewer
  /// than 4 bytes and crashed in ByteReader.
  func testDirectTCPHeaderSplitAcrossTwoReceives() async throws {
    let successSmb2 = smb2Message(status: 0x00000000)
    let frame = DirectTCPPacket(smb2Message: successSmb2).encoded()

    let fragment1 = frame.prefix(2)          // first 2 bytes of DirectTCP header
    let fragment2 = frame.suffix(from: 2)    // header tail + full body

    let serverDone = XCTestExpectation(description: "server finished")
    let (listener, port) = try await startMockServer(
      script: ServerScript(fragments: [Data(fragment1), Data(fragment2)]),
      serverDone: serverDone
    )
    defer { listener.cancel() }

    let connection = Connection(host: "127.0.0.1", port: Int(port))
    defer { connection.disconnect() }

    let responseData = try await connection.send(successSmb2)
    await fulfillment(of: [serverDone], timeout: 5)

    XCTAssertEqual(responseData.count, successSmb2.count)
    XCTAssertTrue(NTStatus(Header(data: responseData).status) == ErrorCode.success)
  }

  /// Header delivered exactly (4 bytes), then the body. Boundary case for
  /// `receive(upTo: 4)` transitioning immediately to `receive(upTo: length)`.
  func testDirectTCPHeaderExactBoundaryThenBody() async throws {
    let successSmb2 = smb2Message(status: 0x00000000)
    let frame = DirectTCPPacket(smb2Message: successSmb2).encoded()

    let fragment1 = frame.prefix(4)
    let fragment2 = frame.suffix(from: 4)

    let serverDone = XCTestExpectation(description: "server finished")
    let (listener, port) = try await startMockServer(
      script: ServerScript(fragments: [Data(fragment1), Data(fragment2)]),
      serverDone: serverDone
    )
    defer { listener.cancel() }

    let connection = Connection(host: "127.0.0.1", port: Int(port))
    defer { connection.disconnect() }

    let responseData = try await connection.send(successSmb2)
    await fulfillment(of: [serverDone], timeout: 5)

    XCTAssertEqual(responseData.count, successSmb2.count)
    XCTAssertTrue(NTStatus(Header(data: responseData).status) == ErrorCode.success)
  }

  // MARK: - #3: PENDING followed by buffer with < 4 bytes (PR #217)

  /// PENDING frame arrives complete, then only 2 bytes of the next DirectTCP header
  /// arrive before a delay. The `.pending` branch must take the `buffer.count < 4`
  /// fallback (old code used `buffer.count > 0` and crashed parsing the partial header).
  func testPendingFollowedByPartialHeaderBelow4Bytes() async throws {
    let pendingSmb2 = smb2Message(status: 0x00000103)
    let successSmb2 = smb2Message(status: 0x00000000)
    let pendingFrame = DirectTCPPacket(smb2Message: pendingSmb2).encoded()
    let successFrame = DirectTCPPacket(smb2Message: successSmb2).encoded()

    // fragment1: full PENDING frame + first 2 bytes of next DirectTCP header
    let fragment1 = pendingFrame + successFrame.prefix(2)
    // fragment2: rest of SUCCESS frame
    let fragment2 = successFrame.suffix(from: 2)

    let serverDone = XCTestExpectation(description: "server finished")
    let (listener, port) = try await startMockServer(
      script: ServerScript(fragments: [Data(fragment1), Data(fragment2)]),
      serverDone: serverDone
    )
    defer { listener.cancel() }

    let connection = Connection(host: "127.0.0.1", port: Int(port))
    defer { connection.disconnect() }

    let responseData = try await connection.send(successSmb2)
    await fulfillment(of: [serverDone], timeout: 5)

    XCTAssertEqual(responseData.count, successSmb2.count)
    XCTAssertTrue(NTStatus(Header(data: responseData).status) == ErrorCode.success)
  }

  // MARK: - #4: PENDING followed by exactly 4 bytes (full header, zero body)

  /// Header of next message is present (4 bytes) but body has 0 bytes, so the
  /// `4 + length` check must trigger the `receive(completion:)` fallback.
  func testPendingFollowedByExactlyFourBytesThenBody() async throws {
    let pendingSmb2 = smb2Message(status: 0x00000103)
    let successSmb2 = smb2Message(status: 0x00000000)
    let pendingFrame = DirectTCPPacket(smb2Message: pendingSmb2).encoded()
    let successFrame = DirectTCPPacket(smb2Message: successSmb2).encoded()

    // fragment1: PENDING frame + exact 4-byte DirectTCP header of SUCCESS
    let fragment1 = pendingFrame + successFrame.prefix(4)
    // fragment2: SUCCESS body
    let fragment2 = successFrame.suffix(from: 4)

    let serverDone = XCTestExpectation(description: "server finished")
    let (listener, port) = try await startMockServer(
      script: ServerScript(fragments: [Data(fragment1), Data(fragment2)]),
      serverDone: serverDone
    )
    defer { listener.cancel() }

    let connection = Connection(host: "127.0.0.1", port: Int(port))
    defer { connection.disconnect() }

    let responseData = try await connection.send(successSmb2)
    await fulfillment(of: [serverDone], timeout: 5)

    XCTAssertEqual(responseData.count, successSmb2.count)
    XCTAssertTrue(NTStatus(Header(data: responseData).status) == ErrorCode.success)
  }

  // MARK: - #6: PENDING followed by exactly 4+length bytes (no trailing)

  /// Entire SUCCESS frame arrives in one shot right after PENDING. Validates the
  /// happy path of the `.pending` branch when the buffer has exactly `4 + length`.
  func testPendingFollowedByExactlyCompleteSuccessFrame() async throws {
    let pendingSmb2 = smb2Message(status: 0x00000103)
    let successSmb2 = smb2Message(status: 0x00000000)
    let pendingFrame = DirectTCPPacket(smb2Message: pendingSmb2).encoded()
    let successFrame = DirectTCPPacket(smb2Message: successSmb2).encoded()

    let fragment1 = pendingFrame + successFrame

    let serverDone = XCTestExpectation(description: "server finished")
    let (listener, port) = try await startMockServer(
      script: ServerScript(fragments: [Data(fragment1)]),
      serverDone: serverDone
    )
    defer { listener.cancel() }

    let connection = Connection(host: "127.0.0.1", port: Int(port))
    defer { connection.disconnect() }

    let responseData = try await connection.send(successSmb2)
    await fulfillment(of: [serverDone], timeout: 5)

    XCTAssertEqual(responseData.count, successSmb2.count)
    XCTAssertTrue(NTStatus(Header(data: responseData).status) == ErrorCode.success)
  }

  // MARK: - #7: Large-payload multi-segment receive (PR #219)

  /// Splits a large SMB2 response (~64 KiB body) into many small TCP fragments.
  /// The old `minimumIncompleteLength: 0` path would throw `noData` once content
  /// became nil between segments and stall the download. The fix must complete.
  func testLargeResponseReceivedInManySmallFragments() async throws {
    // Build a DirectTCP frame containing: SMB2 header (64 bytes) + 64 KiB payload.
    // The header's own structure isn't used after the first 64 bytes; anything
    // in the trailing bytes is opaque to Connection (it just forwards it).
    let headerBytes = smb2Message(status: 0x00000000)
    var payload = Data(count: 64 * 1024)
    for i in 0..<payload.count { payload[i] = UInt8(i & 0xFF) }
    let body = headerBytes + payload
    let frame = DirectTCPPacket(smb2Message: body).encoded()

    // Split into ~1 KiB chunks
    let chunkSize = 1024
    var fragments: [Data] = []
    var offset = 0
    while offset < frame.count {
      let end = min(offset + chunkSize, frame.count)
      fragments.append(Data(frame[offset..<end]))
      offset = end
    }

    let serverDone = XCTestExpectation(description: "server finished")
    let (listener, port) = try await startMockServer(
      script: ServerScript(fragments: fragments, interFragmentDelaySeconds: 0.005),
      serverDone: serverDone
    )
    defer { listener.cancel() }

    let connection = Connection(host: "127.0.0.1", port: Int(port))
    defer { connection.disconnect() }

    let responseData = try await connection.send(headerBytes)
    await fulfillment(of: [serverDone], timeout: 30)

    XCTAssertEqual(responseData.count, body.count)
    XCTAssertTrue(NTStatus(Header(data: responseData).status) == ErrorCode.success)
  }

  // MARK: - #9: Server EOF surfaces as ConnectionError.disconnected

  /// Server accepts the connection, receives the request, then closes without
  /// sending any data. `receive` must surface `ConnectionError.disconnected`.
  func testServerClosesWithoutRespondingThrowsDisconnected() async throws {
    let listenerQueue = DispatchQueue(label: "test.mock.server.close")
    let tcpOptions = NWProtocolTCP.Options()
    tcpOptions.noDelay = true
    let params = NWParameters(tls: nil, tcp: tcpOptions)
    let listener = try NWListener(using: params, on: .any)
    listener.newConnectionHandler = { serverConn in
      serverConn.start(queue: listenerQueue)
      serverConn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { _, _, _, _ in
        // Immediately close; send no response.
        serverConn.cancel()
      }
    }

    let port: UInt16 = try await withCheckedThrowingContinuation { continuation in
      let latch = ResumeLatch()
      listener.stateUpdateHandler = { state in
        switch state {
        case .ready:
          guard latch.trip() else { return }
          continuation.resume(returning: listener.port!.rawValue)
        case .failed(let error):
          guard latch.trip() else { return }
          continuation.resume(throwing: error)
        default: break
        }
      }
      listener.start(queue: listenerQueue)
    }
    defer { listener.cancel() }

    let connection = Connection(host: "127.0.0.1", port: Int(port))
    defer { connection.disconnect() }

    do {
      _ = try await connection.send(smb2Message(status: 0x00000000))
      XCTFail("Expected ConnectionError.disconnected")
    } catch let error as ConnectionError {
      guard case .disconnected = error else {
        XCTFail("Expected .disconnected, got \(error)")
        return
      }
    } catch {
      XCTFail("Unexpected error type: \(error)")
    }
  }

  // MARK: - #10: disconnect() during an in-flight connect() must not hang (PR #218)

  /// With the old `disconnect()` that cleared `stateUpdateHandler` synchronously,
  /// an in-flight `connect()` continuation could be dropped, hanging forever.
  /// The fix keeps the handler attached and relies on `[weak self]` so the
  /// `.cancelled` state update resumes the continuation with `.cancelled`.
  func testDisconnectDuringInflightConnectResumesWithCancelled() async throws {
    // 198.51.100.1 is TEST-NET-1 (RFC 5737); connections will never complete.
    let connection = Connection(host: "198.51.100.1", port: 445)

    let started = XCTestExpectation(description: "connect task started")

    let task = Task { () -> Error? in
      started.fulfill()
      do {
        try await connection.connect()
        return nil
      } catch {
        return error
      }
    }

    await fulfillment(of: [started], timeout: 2)
    // Give connect() a moment to register its stateUpdateHandler.
    try await Task.sleep(nanoseconds: 200_000_000)

    connection.disconnect()

    // The task must resume promptly (no hang).
    let deadline = Date().addingTimeInterval(5)
    let result = await withTaskGroup(of: Error?.self) { group -> Error? in
      group.addTask { await task.value }
      group.addTask {
        while Date() < deadline {
          if task.isCancelled { return nil }
          try? await Task.sleep(nanoseconds: 50_000_000)
        }
        return nil
      }
      let first = await group.next() ?? nil
      group.cancelAll()
      return first
    }

    // Accept any ConnectionError (cancelled / disconnected) or NWError — the key
    // guarantee is that we DO NOT hang.
    XCTAssertNotNil(result, "connect() should have thrown after disconnect(), not hung")
  }

  // MARK: - #13: retain cycle check — Connection deallocates after disconnect

  /// Drives connect → send → disconnect against a mock server and verifies that
  /// the Connection instance is released. With the old retain-cycle bug the
  /// NWConnection's stateUpdateHandler closure captured `self` strongly and the
  /// object leaked.
  func testConnectionIsReleasedAfterDisconnect() async throws {
    let successSmb2 = smb2Message(status: 0x00000000)
    let frame = DirectTCPPacket(smb2Message: successSmb2).encoded()

    let (listener, port) = try await startMockServer(
      script: ServerScript(fragments: [Data(frame)]),
      serverDone: nil
    )
    defer { listener.cancel() }

    weak var weakConnection: Connection?
    do {
      let connection = Connection(host: "127.0.0.1", port: Int(port))
      weakConnection = connection
      _ = try await connection.send(successSmb2)
      connection.disconnect()
      // Give NWConnection a moment to emit its .cancelled state update so its
      // handler reference is released.
      try await Task.sleep(nanoseconds: 200_000_000)
    }

    // After the scope exits, the Connection should be deallocated. If the retain
    // cycle is back, NWConnection keeps the closure (and `self`) alive.
    XCTAssertNil(weakConnection, "Connection leaked — retain cycle via stateUpdateHandler?")
  }
}
