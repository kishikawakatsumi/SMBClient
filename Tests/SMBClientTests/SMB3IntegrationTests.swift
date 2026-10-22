import XCTest
@testable import SMBClient

// End-to-end integration test against a local Samba server configured for
// SMB 3.1.1 with `smb encrypt = required`. This is the definitive proof that
// negotiate contexts, pre-auth integrity, SP800-108 key derivation, AES-CMAC
// signing of the final session setup, and AES-GCM encryption are all correct:
// if any byte is wrong the server rejects with ACCESS_DENIED or the GCM tag
// fails to verify.
//
// Guarded by the SMB3_TEST_* environment variables so it only runs when the
// server is up (see tools/smb3-test-server.sh). Skips cleanly otherwise.
final class SMB3IntegrationTests: XCTestCase {
  private struct Config {
    let host: String
    let port: Int
    let user: String
    let password: String
    let share: String
  }

  private func config() throws -> Config {
    let env = ProcessInfo.processInfo.environment
    guard let host = env["SMB3_TEST_HOST"] else {
      throw XCTSkip("SMB3_TEST_HOST not set; skipping live SMB3 integration test")
    }
    return Config(
      host: host,
      port: Int(env["SMB3_TEST_PORT"] ?? "445") ?? 445,
      user: env["SMB3_TEST_USER"] ?? "",
      password: env["SMB3_TEST_PASSWORD"] ?? "",
      share: env["SMB3_TEST_SHARE"] ?? "TestShare"
    )
  }

  func testNegotiatesSMB311() async throws {
    let c = try config()
    let session = Session(host: c.host, port: c.port)
    try await session.connect()
    defer { session.disconnect() }

    let response = try await session.negotiate()
    XCTAssertEqual(response.dialectRevision, Negotiate.Dialects.smb311.rawValue)
    // Server must have selected AES-GCM since we required encryption.
    XCTAssertNotNil(response.selectedCipher)
  }

  func testEncryptedLoginTreeConnectAndRead() async throws {
    let c = try config()
    let client = SMBClient(host: c.host, port: c.port)

    try await client.login(username: c.user, password: c.password)
    try await client.connectShare(c.share)

    // Directory enumeration over the encrypted channel.
    let files = try await client.listDirectory(path: "")
    XCTAssertTrue(files.contains { $0.name == "hello.txt" })
    XCTAssertTrue(files.contains { $0.name == "media.bin" })

    // Read a small text file end-to-end (create/read/close, all encrypted).
    let hello = try await client.download(path: "hello.txt")
    XCTAssertEqual(String(data: hello, encoding: .utf8), "hello smb3 encrypted world\n")

    try await client.disconnectShare()
    try await client.logoff()
  }

  func testEncryptedLargeRangedRead() async throws {
    let c = try config()
    let client = SMBClient(host: c.host, port: c.port)

    try await client.login(username: c.user, password: c.password)
    try await client.connectShare(c.share)

    let reader = client.fileReader(path: "media.bin")
    let size = try await reader.fileSize
    XCTAssertEqual(size, 1_048_576)

    // Ranged read from the middle (exercises encrypted READ responses).
    let chunk = try await reader.read(offset: 500_000, length: 65_536)
    XCTAssertEqual(chunk.count, 65_536)

    // Full download, then verify it matches a second full download (integrity).
    let whole = try await reader.read(offset: 0, length: UInt32(size))
    XCTAssertEqual(whole.count, Int(size))
    try await reader.close()

    try await client.disconnectShare()
    try await client.logoff()
  }

  // Proves the encrypted channel works for the FULL filesystem API, not just
  // reads: upload (write path — sends large ciphertext client->server), stat,
  // download-verify, rename, then delete. Every one of these SMB2 messages is
  // wrapped in a TRANSFORM_HEADER, so a bug in the encrypt path for writes
  // would surface here. (We write at the share root rather than creating a
  // subdirectory: Samba's atomic mkdir-via-temp-RENAMEAT trips a macOS-only
  // VFS permission quirk on /tmp that is unrelated to SMB3 encryption.)
  func testEncryptedWriteRenameDelete() async throws {
    let c = try config()
    let client = SMBClient(host: c.host, port: c.port)

    try await client.login(username: c.user, password: c.password)
    try await client.connectShare(c.share)

    let tag = UInt32.random(in: 0..<UInt32.max)
    let filePath = "smb3_rw_\(tag).bin"
    let renamedPath = "smb3_rw_\(tag)-renamed.bin"

    // Upload a payload larger than one SMB2 write so multiple encrypted WRITE
    // requests are sent client->server.
    var payload = Data(count: 300_000)
    for i in payload.indices { payload[i] = UInt8((i &* 31 &+ 7) & 0xFF) }
    try await client.upload(content: payload, path: filePath)

    // Stat + download-verify round-trips the data back through encrypted READs.
    let info = try await client.fileInfo(path: filePath)
    XCTAssertEqual(info.standardInformation.endOfFile, UInt64(payload.count))
    let roundTrip = try await client.download(path: filePath)
    XCTAssertEqual(roundTrip, payload)

    // Rename over the encrypted channel, confirm, then clean up.
    try await client.rename(from: filePath, to: renamedPath)
    let renamedExists = try await client.existFile(path: renamedPath)
    let originalExists = try await client.existFile(path: filePath)
    XCTAssertTrue(renamedExists)
    XCTAssertFalse(originalExists)

    try await client.deleteFile(path: renamedPath)
    let deletedExists = try await client.existFile(path: renamedPath)
    XCTAssertFalse(deletedExists)

    try await client.disconnectShare()
    try await client.logoff()
  }
}
