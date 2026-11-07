import XCTest
@testable import SMBClient

final class ErrorResponseTests: XCTestCase {
  func testHeaderOnlyErrorResponse() {
    let data = Self.header(status: ErrorCode.userSessionDeleted.rawValue)

    let response = ErrorResponse(data: data)

    XCTAssertTrue(NTStatus(response.header.status) == ErrorCode.userSessionDeleted)
    XCTAssertEqual(response.structureSize, 0)
    XCTAssertEqual(response.errorContextCount, 0)
  }

  func testFullErrorResponse() {
    var data = Self.header(status: ErrorCode.logonFailure.rawValue)
    data += Data([0x09, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00])

    let response = ErrorResponse(data: data)

    XCTAssertTrue(NTStatus(response.header.status) == ErrorCode.logonFailure)
    XCTAssertEqual(response.structureSize, 9)
  }

  /// A 64-byte SMB2 response header carrying `status`.
  private static func header(status: UInt32) -> Data {
    var data = Data(count: 64)
    data.replaceSubrange(0..<4, with: [0xFE, 0x53, 0x4D, 0x42])
    data.replaceSubrange(4..<6, with: [64, 0])
    withUnsafeBytes(of: status.littleEndian) { data.replaceSubrange(8..<12, with: $0) }
    return data
  }
}
