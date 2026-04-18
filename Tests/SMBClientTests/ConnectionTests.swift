import XCTest
import Network
@testable import SMBClient

final class ConnectionTests: XCTestCase {
  /// Builds a minimal 64-byte SMB2 header with the given status code and flags.
  private func smb2Header(status: UInt32, flags: UInt32 = 0x00000001) -> Data {
    var bytes = Data(count: 64)
    bytes[0] = 0xFE; bytes[1] = 0x53; bytes[2] = 0x4D; bytes[3] = 0x42  // protocol id
    bytes[4] = 0x40; bytes[5] = 0x00                                      // structureSize = 64
    bytes[6] = 0x01; bytes[7] = 0x00                                      // creditCharge = 1
    bytes[8]  = UInt8((status      ) & 0xFF)                              // status (little-endian)
    bytes[9]  = UInt8((status >>  8) & 0xFF)
    bytes[10] = UInt8((status >> 16) & 0xFF)
    bytes[11] = UInt8((status >> 24) & 0xFF)
    bytes[16] = UInt8((flags       ) & 0xFF)                              // flags (little-endian)
    bytes[17] = UInt8((flags >>  8) & 0xFF)
    bytes[18] = UInt8((flags >> 16) & 0xFF)
    bytes[19] = UInt8((flags >> 24) & 0xFF)
    return bytes
  }

  /// Reproduces the off-by-4 bug in `Connection.receive(completion:)`.
  ///
  /// When a STATUS_PENDING response arrives and `self.buffer` already contains the
  /// 4-byte DirectTCP header **plus some but not all** bytes of the follow-up SUCCESS
  /// message, the guard condition must check `self.buffer.count < 4 + length`.
  /// The old, buggy guard `self.buffer.count < length` incorrectly skips waiting for
  /// the missing bytes and tries to parse a truncated packet, causing an index-out-of-
  /// range crash or a corrupt response.
  ///
  /// The mock server sends:
  ///   • fragment1 – full PENDING DirectTCP frame (68 bytes)
  ///                 + first 67 bytes of SUCCESS DirectTCP frame (one byte short)
  ///   • fragment2 – the last 1 byte of the SUCCESS DirectTCP frame
  ///
  /// With the fix the client waits for fragment2 before parsing and returns the correct
  /// SUCCESS response. Without the fix it crashes on the 63-byte truncated header read.
  func testPendingFollowedBySuccessWithFragmentedTCPDelivery() async throws {
    // STATUS_PENDING (0x103) with asyncCommand flag; STATUS_SUCCESS (0x00) with serverToRedir flag
    let pendingSmb2 = smb2Header(status: 0x00000103, flags: 0x00000003)
    let successSmb2 = smb2Header(status: 0x00000000, flags: 0x00000001)

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
    let listener = try NWListener(using: .tcp, on: .any)
    let listenerQueue = DispatchQueue(label: "test.mock.server")

    let assignedPort: UInt16 = try await withCheckedThrowingContinuation { continuation in
      listener.stateUpdateHandler = { state in
        switch state {
        case .ready:
          continuation.resume(returning: listener.port!.rawValue)
        case .failed(let error):
          continuation.resume(throwing: error)
        default:
          break
        }
      }
      listener.start(queue: listenerQueue)
    }
    defer { listener.cancel() }

    let serverDone = XCTestExpectation(description: "server finished sending both fragments")
    listener.newConnectionHandler = { serverConn in
      serverConn.start(queue: listenerQueue)
      // Consume the client's request (the content is ignored by the mock server)
      serverConn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { _, _, _, _ in
        // Send fragment1: full PENDING frame + all-but-last-byte of SUCCESS frame
        serverConn.send(content: fragment1, completion: .contentProcessed { _ in
          // Introduce a small pause so the two sends are delivered as separate TCP
          // segments, reproducing the fragmented receive that triggers the bug
          listenerQueue.asyncAfter(deadline: .now() + 0.1) {
            serverConn.send(content: fragment2, completion: .contentProcessed { _ in
              serverDone.fulfill()
            })
          }
        })
      }
    }

    // ---- Connect and send a dummy request; server ignores its content ----
    let connection = Connection(host: "127.0.0.1", port: Int(assignedPort))
    defer { connection.disconnect() }

    let responseData = try await connection.send(smb2Header(status: 0))

    await fulfillment(of: [serverDone], timeout: 5)

    // The response must be the complete SUCCESS SMB2 message (64 bytes) with
    // STATUS_SUCCESS in its header
    XCTAssertEqual(responseData.count, successSmb2.count)
    XCTAssertTrue(NTStatus(Header(data: responseData).status) == .success)
  }
}
