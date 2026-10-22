import XCTest
@testable import SMBClient

/// Known-answer tests for the SMB3 crypto primitives, verified against
/// published NIST vectors so the crypto is provable offline (independent of any
/// live server).
final class SMB3CryptoTests: XCTestCase {
  // AES-128-CMAC, NIST SP800-38B Appendix D.1 example vectors.
  // Key = 2b7e151628aed2a6abf7158809cf4f3c
  private let cmacKey = Data("2b7e151628aed2a6abf7158809cf4f3c")!

  func testAESCMACEmptyMessage() {
    // Mlen = 0
    let mac = Crypto.aesCMAC(key: cmacKey, data: Data())
    XCTAssertEqual(mac.hex, "bb1d6929e95937287fa37d129b756746")
  }

  func testAESCMACOneBlock() {
    // Mlen = 128
    let msg = Data("6bc1bee22e409f96e93d7e117393172a")!
    let mac = Crypto.aesCMAC(key: cmacKey, data: msg)
    XCTAssertEqual(mac.hex, "070a16b46b4d4144f79bdd9dd04a287c")
  }

  func testAESCMACPartialBlock() {
    // Mlen = 320 (requires the K2 subkey / padded final block path)
    let msg = Data("6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411")!
    let mac = Crypto.aesCMAC(key: cmacKey, data: msg)
    XCTAssertEqual(mac.hex, "dfa66747de9ae63030ca32611497c827")
  }

  func testAESCMACFullFourBlocks() {
    // Mlen = 512 (complete final block => K1 path)
    let msg = Data("6bc1bee22e409f96e93d7e117393172aae2d8a571e03ac9c9eb76fac45af8e5130c81c46a35ce411e5fbc1191a0a52eff69f2445df4f9b17ad2b417be66c3710")!
    let mac = Crypto.aesCMAC(key: cmacKey, data: msg)
    XCTAssertEqual(mac.hex, "51f0bebf7e3b9d92fc49741779363cfe")
  }

  // SHA-512 sanity (NIST): empty and "abc".
  func testSHA512() {
    XCTAssertEqual(
      Crypto.sha512(Data()).hex,
      "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce47d0d13c5d85f2b0ff8318d2877eec2f63b931bd47417a81a538327af927da3e"
    )
    XCTAssertEqual(
      Crypto.sha512("abc".data(using: .utf8)!).hex,
      "ddaf35a193617abacc417349ae20413112e6fa4e89a97ea20a9eeee64b55d39a2192992a274fc1a836ba3c23a3feebbd454d4423643ce80e2a9ac94fa54ca49f"
    )
  }

  // AES-ECB single block, FIPS-197 / SP800-38A example.
  func testAESEncryptECB() {
    let key = Data("2b7e151628aed2a6abf7158809cf4f3c")!
    let pt = Data("6bc1bee22e409f96e93d7e117393172a")!
    XCTAssertEqual(Crypto.aesEncryptECB(key: key, data: pt).hex, "3ad77bb40d7a3660a89ecaf32466ef97")
  }

  // AES-128-GCM, NIST GCM test case 4 (12-byte IV, with AAD).
  func testAESGCMSealKnownAnswer() throws {
    let key = Data("feffe9928665731c6d6a8f9467308308")!
    let nonce = Data("cafebabefacedbaddecaf888")!
    let pt = Data("d9313225f88406e5a55909c5aff5269a86a7a9531534f7da2e4c303d8a318a721c3c0c95956809532fcf0e2449a6b525b16aedf5aa0de657ba637b39")!
    let aad = Data("feedfacedeadbeeffeedfacedeadbeefabaddad2")!
    let (ct, tag) = try Crypto.aesGCMSeal(key: key, nonce: nonce, plaintext: pt, aad: aad)
    XCTAssertEqual(ct.hex, "42831ec2217774244b7221b784d0d49ce3aa212f2c02a4e035c17e2329aca12e21d514b25466931c7d8f6a5aac84aa051ba30b396a0aac973d58e091")
    XCTAssertEqual(tag.hex, "5bc94fbc3221a5db94fae95ae7121a47")
  }

  // AES-GCM round-trip through our seal/open with SMB-shaped nonce/aad.
  func testAESGCMRoundTrip() throws {
    let key = Crypto.randomBytes(count: 16)
    let nonce = Crypto.randomBytes(count: 12)
    let aad = Crypto.randomBytes(count: 32)
    let pt = Crypto.randomBytes(count: 200)
    let (ct, tag) = try Crypto.aesGCMSeal(key: key, nonce: nonce, plaintext: pt, aad: aad)
    let recovered = try Crypto.aesGCMOpen(key: key, nonce: nonce, ciphertext: ct, tag: tag, aad: aad)
    XCTAssertEqual(recovered, pt)
    // Tamper detection.
    var badTag = tag; badTag[badTag.startIndex] ^= 0xff
    XCTAssertThrowsError(try Crypto.aesGCMOpen(key: key, nonce: nonce, ciphertext: ct, tag: badTag, aad: aad))
  }

  // SP800-108 counter-mode KDF (HMAC-SHA256 PRF), SMB3 input construction.
  // This validates our exact input layout — counter(4 BE) || label || 0x00 ||
  // context || L(4 BE) — and the 128-bit truncation. hmacSHA256 is itself a
  // trusted CommonCrypto primitive (KAT'd elsewhere); interop correctness of
  // the derived keys is additionally proven end-to-end against a live server.
  func testSP800108CounterKDFConstruction() {
    let key = Data("0102030405060708090a0b0c0d0e0f10")!
    let label = "SMBSigningKey".data(using: .ascii)!
    let context = Data("aabbccddeeff00112233445566778899")!

    let derived = Crypto.sp800108CounterKDF(key: key, label: label, context: context, lengthInBits: 128)

    // Reference: single iteration is enough for 128 bits with a 256-bit PRF.
    // Mirrors the KDF's input layout: [i]2 || Label || 0x00 || Context || [L]2.
    var counterBE = UInt32(1).bigEndian
    var lenBE = UInt32(128).bigEndian
    let input = withUnsafeBytes(of: &counterBE) { Data($0) }
      + label + Data([0x00]) + context
      + withUnsafeBytes(of: &lenBE) { Data($0) }
    let expected = Data(Crypto.hmacSHA256(key: key, data: input).prefix(16))

    XCTAssertEqual(derived, expected)
    XCTAssertEqual(derived.count, 16)
  }
}
