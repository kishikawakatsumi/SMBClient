import XCTest
@testable import SMBClient

final class CryptoTests: XCTestCase {
  func testMD4() async throws {
    XCTAssertEqual(Crypto.md4("".data(using: .utf8)!).hex, "31d6cfe0d16ae931b73c59d7e0c089c0")
    XCTAssertEqual(Crypto.md4("a".data(using: .utf8)!).hex, "bde52cb31de33e46245e05fbdbd6fb24")
    XCTAssertEqual(Crypto.md4("abc".data(using: .utf8)!).hex, "a448017aaf21d8525fc10ae87aa6729d")
    XCTAssertEqual(Crypto.md4("message digest".data(using: .utf8)!).hex, "d9130a8164549fe818874806e1c7014b")
    XCTAssertEqual(Crypto.md4("abcdefghijklmnopqrstuvwxyz".data(using: .utf8)!).hex, "d79e1c308aa5bbcdeea8ed63df412da9")
    XCTAssertEqual(Crypto.md4("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789".data(using: .utf8)!).hex, "043f8582f241db351ce627e153e7f0e4")
    XCTAssertEqual(Crypto.md4("12345678901234567890123456789012345678901234567890123456789012345678901234567890".data(using: .utf8)!).hex, "e33b4ddc9c38f2199c3e7b164fcc0536")
    XCTAssertEqual(Crypto.md4("test".data(using: .utf8)!).hex, "db346d691d7acc4dc2625db19f9e3f52")
  }
}
