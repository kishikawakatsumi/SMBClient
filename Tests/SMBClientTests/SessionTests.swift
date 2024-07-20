import XCTest
@testable import SMBClient

final class SessionTests: XCTestCase {
  func testLoginSucceeded() async throws {
    let session = Session(host: "localhost", port: 4445)

    try await session.connect()
    try await session.login(username: "alice", password: "alipass")
    
    try await session.treeConnect(path: "Alice Share")

    let files = try await session.queryDirectory(path: "", pattern: "*")
    XCTAssertFalse(files.isEmpty)

    try await session.treeDisconnect()
    try await session.logoff()
  }
}
