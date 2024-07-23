import XCTest
@testable import SMBClient

final class SessionTests: XCTestCase {
  func testNegotiate() async throws {
    let session = Session(host: "127.0.0.1", port: 4445)

    try await session.connect()
    let response = try await session.negotiate()
    XCTAssertEqual(response.dialectRevision , Negotiate.Dialects.smb210.rawValue)
  }

  func testLoginSucceeded() async throws {
    let session = Session(host: "localhost", port: 4445)

    try await session.connect()
    try await session.negotiate()
    try await session.login(username: "alice", password: "alipass")
    
    try await session.treeConnect(path: "Alice Share")

    let files = try await session.queryDirectory(path: "", pattern: "*")
    XCTAssertFalse(files.isEmpty)

    try await session.treeDisconnect()
    try await session.logoff()
  }
}
