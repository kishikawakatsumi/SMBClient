import XCTest
@testable import SMBClient

final class SessionTests: XCTestCase {
  func testNegotiate() async throws {
    let session = Session(host: "127.0.0.1", port: 4445)

    try await session.connect()

    let response = try await session.negotiate()
    XCTAssertEqual(response.dialectRevision , Negotiate.Dialects.smb210.rawValue)
  }

  func testSessionSetup01() async throws {
    let session = Session(host: "localhost", port: 4445)

    try await session.connect()
    try await session.negotiate()

    try await session.sessionSetup(username: "alice", password: "alipass")
    try await session.logoff()
  }

  func testSessionSetup02() async throws {
    let session = Session(host: "localhost", port: 4445)

    try await session.connect()
    try await session.negotiate()

    try await session.sessionSetup(username: "alice", password: "alipass", domain: ".")
    try await session.logoff()
  }

  func testSessionSetup03() async throws {
    let session = Session(host: "localhost", port: 4445)

    try await session.connect()
    try await session.negotiate()

    try await session.sessionSetup(username: "alice", password: "alipass", domain: ".", workstation: "WORKSTATION")
    try await session.logoff()
  }

  func testSessionSetup04() async throws {
    let session = Session(host: "localhost", port: 4445)

    try await session.connect()
    try await session.negotiate()

    try await session.sessionSetup(username: "alice", password: "alipass")
    try await session.treeConnect(path: "Alice Share")

    let files = try await session.queryDirectory(path: "", pattern: "*")
    XCTAssertFalse(files.isEmpty)

    try await session.treeDisconnect()
    try await session.logoff()
  }

  func testCreate01() async throws {
    let session = Session(host: "localhost", port: 4445)

    try await session.connect()
    try await session.negotiate()

    try await session.sessionSetup(username: "alice", password: "alipass")
    try await session.treeConnect(path: "Alice Share")

    let response = try await session.create(
      desiredAccess: [.readData, .readAttributes, .synchronize],
      fileAttributes: [.directory],
      shareAccess: [.read, .write, .delete],
      createDisposition: .open,
      createOptions: [.directoryFile],
      name: ""
    )
    XCTAssertFalse(response.fileId.isEmpty)

    try await session.treeDisconnect()
    try await session.logoff()
  }

  func testEcho() async throws {
    let session = Session(host: "localhost", port: 4445)

    try await session.connect()
    try await session.negotiate()

    try await session.sessionSetup(username: "alice", password: "alipass")
    try await session.treeConnect(path: "Alice Share")

    let response = try await session.echo()
    print(response)

    try await session.treeDisconnect()
    try await session.logoff()
  }
}
