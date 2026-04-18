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

  /// Reproduces the off-by-4 bug in `Connection.receive(completion:)`.
  ///
  /// When a STATUS_PENDING response arrives and `self.buffer` already contains the
  /// 4-byte DirectTCP header **plus some but not all** bytes of the follow-up SUCCESS
  /// message, the guard condition must check `self.buffer.count < 4 + length`.
  /// The old, buggy guard `self.buffer.count < length` would skip waiting for
  /// the missing bytes and try to parse a truncated packet.
  ///
  /// The mock server sends:
  ///   • fragment1 – full PENDING DirectTCP frame (68 bytes)
  ///                 + first 67 bytes of SUCCESS DirectTCP frame (one byte short)
  ///   • fragment2 – the last 1 byte of the SUCCESS DirectTCP frame
  ///
  /// With the fix the client waits for fragment2 before parsing and returns the correct
  /// SUCCESS response.
  func testPendingFollowedBySuccessWithFragmentedTCPDelivery() async throws {
    let pendingSmb2 = smb2Message(status: 0x00000103)  // STATUS_PENDING
    let successSmb2 = smb2Message(status: 0x00000000)  // STATUS_SUCCESS

    // Wrap each SMB2 message in a DirectTCP envelope (4 + 64 = 68 bytes each)
    let pendingFrame = DirectTCPPacket(smb2Message: pendingSmb2).encoded()
    let successFrame = DirectTCPPacket(smb2Message: successSmb2).encoded()

    // After Connection finishes processing the PENDING frame its internal buffer holds
    // exactly successFrame.prefix(67): 4-byte DirectTCP header + 63 bytes of SMB2 body.
    //
    //   Fixed guard:  67 < (4 + 64) = 68  → TRUE  → waits for the missing byte ✓
    //   Buggy guard:  67 < 64             → FALSE → tries to parse 63-byte body  ✗
    let fragment1 = pendingFrame + successFrame.prefix(successFrame.count - 1)
    let fragment2 = successFrame.suffix(1)

    // ---- Start a local mock TCP server on an OS-assigned port ----
    let listenerQueue = DispatchQueue(label: "test.mock.server")
    let listener = try NWListener(using: .tcp, on: .any)
    let serverDone = XCTestExpectation(description: "server finished sending both fragments")

    // newConnectionHandler must be set before start() or NWListener returns EINVAL
    listener.newConnectionHandler = { serverConn in
      serverConn.start(queue: listenerQueue)
      // Consume the client's request (content is ignored by the mock server)
      serverConn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { _, _, _, _ in
        // Send fragment1: full PENDING frame + all-but-last-byte of SUCCESS frame
        serverConn.send(content: fragment1, completion: .contentProcessed { _ in
          // Small delay so the two sends arrive as separate TCP segments,
          // reproducing the fragmented receive scenario
          listenerQueue.asyncAfter(deadline: .now() + 0.05) {
            serverConn.send(content: fragment2, completion: .contentProcessed { _ in
              serverDone.fulfill()
            })
          }
        })
      }
    }

    let assignedPort: UInt16 = try await withCheckedThrowingContinuation { continuation in
      var resumed = false
      listener.stateUpdateHandler = { state in
        switch state {
        case .ready:
          guard !resumed else { return }
          resumed = true
          continuation.resume(returning: listener.port!.rawValue)
        case .failed(let error):
          guard !resumed else { return }
          resumed = true
          continuation.resume(throwing: error)
        default:
          break
        }
      }
      listener.start(queue: listenerQueue)
    }
    defer { listener.cancel() }

    // ---- Connect and send a dummy request; server ignores its content ----
    let connection = Connection(host: "127.0.0.1", port: Int(assignedPort))
    defer { connection.disconnect() }

    let responseData = try await connection.send(successSmb2)

    await fulfillment(of: [serverDone], timeout: 5)

    // The response must be the complete SUCCESS SMB2 message (64 bytes) with
    // STATUS_SUCCESS in its header
    XCTAssertEqual(responseData.count, successSmb2.count)
    XCTAssertTrue(NTStatus(Header(data: responseData).status) == ErrorCode.success)
  }
}
