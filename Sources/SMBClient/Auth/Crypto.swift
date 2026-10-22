import Foundation
import CommonCrypto
import CryptoKit

enum Crypto {
  public static func randomBytes(count: Int) -> Data {
    var bytes = [UInt8](repeating: 0, count: count)
    CCRandomGenerateBytes(&bytes, bytes.count)
    return Data(bytes)
  }

  public static func md4(_ data: Data) -> Data {
    var paddedData = data

    let messageLengthBits = UInt64(data.count * 8)

    paddedData.append(0x80)

    let messageLengthMod64 = paddedData.count % 64
    let padLength = messageLengthMod64 < 56 ? 56 - messageLengthMod64 : 120 - messageLengthMod64

    if padLength > 0 {
      paddedData.append(contentsOf: [UInt8](repeating: 0, count: padLength))
    }

    var lengthBytes = messageLengthBits.littleEndian
    withUnsafeBytes(of: &lengthBytes) { paddedData.append(contentsOf: $0) }

    var A: UInt32 = 0x67452301
    var B: UInt32 = 0xefcdab89
    var C: UInt32 = 0x98badcfe
    var D: UInt32 = 0x10325476

    let blockCount = paddedData.count / 64
    for i in 0..<blockCount {
      var X = [UInt32](repeating: 0, count: 16)
      for j in 0..<16 {
        let start = i * 64 + j * 4
        let wordBytes = paddedData.subdata(in: start..<start+4)
        X[j] = wordBytes.withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
      }

      let AA = A
      let BB = B
      let CC = C
      let DD = D

      func F(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        return (x & y) | (~x & z)
      }

      func G(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        return (x & y) | (x & z) | (y & z)
      }

      func H(_ x: UInt32, _ y: UInt32, _ z: UInt32) -> UInt32 {
        return x ^ y ^ z
      }

      func leftRotate(_ x: UInt32, by n: UInt32) -> UInt32 {
        return (x << n) | (x >> (32 - n))
      }

      A = leftRotate(A &+ F(B, C, D) &+ X[0], by: 3)
      D = leftRotate(D &+ F(A, B, C) &+ X[1], by: 7)
      C = leftRotate(C &+ F(D, A, B) &+ X[2], by: 11)
      B = leftRotate(B &+ F(C, D, A) &+ X[3], by: 19)
      A = leftRotate(A &+ F(B, C, D) &+ X[4], by: 3)
      D = leftRotate(D &+ F(A, B, C) &+ X[5], by: 7)
      C = leftRotate(C &+ F(D, A, B) &+ X[6], by: 11)
      B = leftRotate(B &+ F(C, D, A) &+ X[7], by: 19)
      A = leftRotate(A &+ F(B, C, D) &+ X[8], by: 3)
      D = leftRotate(D &+ F(A, B, C) &+ X[9], by: 7)
      C = leftRotate(C &+ F(D, A, B) &+ X[10], by: 11)
      B = leftRotate(B &+ F(C, D, A) &+ X[11], by: 19)
      A = leftRotate(A &+ F(B, C, D) &+ X[12], by: 3)
      D = leftRotate(D &+ F(A, B, C) &+ X[13], by: 7)
      C = leftRotate(C &+ F(D, A, B) &+ X[14], by: 11)
      B = leftRotate(B &+ F(C, D, A) &+ X[15], by: 19)

      let k2: UInt32 = 0x5a827999
      A = leftRotate(A &+ G(B, C, D) &+ X[0] &+ k2, by: 3)
      D = leftRotate(D &+ G(A, B, C) &+ X[4] &+ k2, by: 5)
      C = leftRotate(C &+ G(D, A, B) &+ X[8] &+ k2, by: 9)
      B = leftRotate(B &+ G(C, D, A) &+ X[12] &+ k2, by: 13)
      A = leftRotate(A &+ G(B, C, D) &+ X[1] &+ k2, by: 3)
      D = leftRotate(D &+ G(A, B, C) &+ X[5] &+ k2, by: 5)
      C = leftRotate(C &+ G(D, A, B) &+ X[9] &+ k2, by: 9)
      B = leftRotate(B &+ G(C, D, A) &+ X[13] &+ k2, by: 13)
      A = leftRotate(A &+ G(B, C, D) &+ X[2] &+ k2, by: 3)
      D = leftRotate(D &+ G(A, B, C) &+ X[6] &+ k2, by: 5)
      C = leftRotate(C &+ G(D, A, B) &+ X[10] &+ k2, by: 9)
      B = leftRotate(B &+ G(C, D, A) &+ X[14] &+ k2, by: 13)
      A = leftRotate(A &+ G(B, C, D) &+ X[3] &+ k2, by: 3)
      D = leftRotate(D &+ G(A, B, C) &+ X[7] &+ k2, by: 5)
      C = leftRotate(C &+ G(D, A, B) &+ X[11] &+ k2, by: 9)
      B = leftRotate(B &+ G(C, D, A) &+ X[15] &+ k2, by: 13)

      let k3: UInt32 = 0x6ed9eba1
      A = leftRotate(A &+ H(B, C, D) &+ X[0] &+ k3, by: 3)
      D = leftRotate(D &+ H(A, B, C) &+ X[8] &+ k3, by: 9)
      C = leftRotate(C &+ H(D, A, B) &+ X[4] &+ k3, by: 11)
      B = leftRotate(B &+ H(C, D, A) &+ X[12] &+ k3, by: 15)
      A = leftRotate(A &+ H(B, C, D) &+ X[2] &+ k3, by: 3)
      D = leftRotate(D &+ H(A, B, C) &+ X[10] &+ k3, by: 9)
      C = leftRotate(C &+ H(D, A, B) &+ X[6] &+ k3, by: 11)
      B = leftRotate(B &+ H(C, D, A) &+ X[14] &+ k3, by: 15)
      A = leftRotate(A &+ H(B, C, D) &+ X[1] &+ k3, by: 3)
      D = leftRotate(D &+ H(A, B, C) &+ X[9] &+ k3, by: 9)
      C = leftRotate(C &+ H(D, A, B) &+ X[5] &+ k3, by: 11)
      B = leftRotate(B &+ H(C, D, A) &+ X[13] &+ k3, by: 15)
      A = leftRotate(A &+ H(B, C, D) &+ X[3] &+ k3, by: 3)
      D = leftRotate(D &+ H(A, B, C) &+ X[11] &+ k3, by: 9)
      C = leftRotate(C &+ H(D, A, B) &+ X[7] &+ k3, by: 11)
      B = leftRotate(B &+ H(C, D, A) &+ X[15] &+ k3, by: 15)

      A = A &+ AA
      B = B &+ BB
      C = C &+ CC
      D = D &+ DD
    }

    var digest = Data()
    withUnsafeBytes(of: A.littleEndian) { digest.append(contentsOf: $0) }
    withUnsafeBytes(of: B.littleEndian) { digest.append(contentsOf: $0) }
    withUnsafeBytes(of: C.littleEndian) { digest.append(contentsOf: $0) }
    withUnsafeBytes(of: D.littleEndian) { digest.append(contentsOf: $0) }

    return digest
  }

  public static func hmacMD5(key: Data, data: Data) -> Data {
    let context = UnsafeMutablePointer<CCHmacContext>.allocate(capacity: 1)
    defer { context.deallocate() }
    CCHmacInit(context, CCHmacAlgorithm(kCCHmacAlgMD5), (key as NSData).bytes, size_t(key.count))
    CCHmacUpdate(context, (data as NSData).bytes, size_t(data.count))
    var hmac = Array<UInt8>(repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
    CCHmacFinal(context, &hmac)
    return Data(hmac)
  }

  public static func hmacSHA256(key: Data, data: Data) -> Data {
    let context = UnsafeMutablePointer<CCHmacContext>.allocate(capacity: 1)
    defer { context.deallocate() }
    CCHmacInit(context, CCHmacAlgorithm(kCCHmacAlgSHA256), (key as NSData).bytes, size_t(key.count))
    CCHmacUpdate(context, (data as NSData).bytes, size_t(data.count))
    var hmac = Array<UInt8>(repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
    CCHmacFinal(context, &hmac)
    return Data(hmac)
  }

  public static func rc4(key: Data, data: Data) -> Data {
    let cryptData = NSMutableData(length: Int((data.count)))!
    var numBytesEncrypted :size_t = 0
    CCCrypt(
      CCOperation(kCCEncrypt),
      CCAlgorithm(kCCAlgorithmRC4),
      0,
      (key as NSData).bytes,
      key.count,
      nil,
      (data as NSData).bytes,
      data.count,
      cryptData.mutableBytes,
      cryptData.length,
      &numBytesEncrypted
    )
    return cryptData as Data
  }

  // MARK: - SMB3 primitives

  public static func sha512(_ data: Data) -> Data {
    var digest = [UInt8](repeating: 0, count: Int(CC_SHA512_DIGEST_LENGTH))
    data.withUnsafeBytes { _ = CC_SHA512($0.baseAddress, CC_LONG(data.count), &digest) }
    return Data(digest)
  }

  /// AES-ECB encryption of `data` (a whole number of 16-byte blocks) with no
  /// padding. Used as the block cipher underneath AES-CMAC.
  public static func aesEncryptECB(key: Data, data: Data) -> Data {
    let out = NSMutableData(length: data.count + kCCBlockSizeAES128)!
    var moved: size_t = 0
    let status = CCCrypt(
      CCOperation(kCCEncrypt),
      CCAlgorithm(kCCAlgorithmAES),
      CCOptions(kCCOptionECBMode),   // no kCCOptionPKCS7Padding => no padding
      (key as NSData).bytes, key.count,
      nil,
      (data as NSData).bytes, data.count,
      out.mutableBytes, out.length,
      &moved
    )
    precondition(status == kCCSuccess, "AES-ECB failed: \(status)")
    return out.subdata(with: NSRange(location: 0, length: moved))
  }

  /// AES-CMAC (NIST SP800-38B). Returns the full 16-byte MAC.
  public static func aesCMAC(key: Data, data: Data) -> Data {
    let blockSize = 16
    let zero = Data(count: blockSize)

    // Subkey generation.
    let L = aesEncryptECB(key: key, data: zero)
    let rb: UInt8 = 0x87
    func shiftLeftOne(_ input: Data) -> (Data, UInt8) {
      var out = Data(count: input.count)
      var overflow: UInt8 = 0
      for i in stride(from: input.count - 1, through: 0, by: -1) {
        let b = input[input.startIndex + i]
        out[out.startIndex + i] = (b << 1) | overflow
        overflow = (b & 0x80) != 0 ? 1 : 0
      }
      return (out, overflow)
    }
    func deriveSubkey(_ input: Data) -> Data {
      let (shifted, carry) = shiftLeftOne(input)
      guard carry == 1 else { return shifted }
      var k = shifted
      k[k.index(k.startIndex, offsetBy: blockSize - 1)] ^= rb
      return k
    }
    let k1 = deriveSubkey(L)
    let k2 = deriveSubkey(k1)

    // Message chunking.
    let n = (data.count + blockSize - 1) / blockSize
    let lastComplete = data.count > 0 && data.count % blockSize == 0
    let blockCount = max(n, 1)

    var lastBlock: Data
    if lastComplete {
      lastBlock = xor(Data(data.suffix(blockSize)), k1)
    } else {
      let remainder = data.count % blockSize
      var padded = Data(data.suffix(remainder))
      padded.append(0x80)
      padded.append(contentsOf: [UInt8](repeating: 0, count: blockSize - remainder - 1))
      lastBlock = xor(padded, k2)
    }

    var x = Data(count: blockSize)
    for i in 0..<(blockCount - 1) {
      let start = data.index(data.startIndex, offsetBy: i * blockSize)
      let end = data.index(start, offsetBy: blockSize)
      let block = Data(data[start..<end])
      x = aesEncryptECB(key: key, data: xor(x, block))
    }
    let y = xor(x, lastBlock)
    return aesEncryptECB(key: key, data: y)
  }

  /// SP800-108 KDF in counter mode with HMAC-SHA256 as the PRF. Produces
  /// `lengthInBits`-bit output (SMB3 uses 128). The fixed input is assembled as
  /// `[i]2 || Label || 0x00 || Context || [L]2`; callers pass the bare `label`
  /// (e.g. "SMBSigningKey") and `context` — the single 0x00 label/context
  /// separator is inserted here.
  public static func sp800108CounterKDF(key: Data, label: Data, context: Data, lengthInBits: UInt32) -> Data {
    var output = Data()
    let iterations = (Int(lengthInBits) + 255) / 256
    var i: UInt32 = 1
    var lenBE = lengthInBits.bigEndian
    let lenData = withUnsafeBytes(of: &lenBE) { Data($0) }
    while output.count < (Int(lengthInBits) + 7) / 8 {
      if Int(i) > iterations + 1 { break }
      var counterBE = i.bigEndian
      let counterData = withUnsafeBytes(of: &counterBE) { Data($0) }
      // [i]2 || Label || 0x00 || Context || [L]2
      let input = counterData + label + Data([0x00]) + context + lenData
      output += hmacSHA256(key: key, data: input)
      i &+= 1
    }
    return Data(output.prefix((Int(lengthInBits) + 7) / 8))
  }

  static func xor(_ a: Data, _ b: Data) -> Data {
    let n = Swift.min(a.count, b.count)
    var out = Data(count: n)
    for i in 0..<n {
      out[out.startIndex + i] = a[a.startIndex + i] ^ b[b.startIndex + i]
    }
    return out
  }

  /// AES-GCM seal. `nonce` must be 12 bytes. Returns (ciphertext, 16-byte tag).
  public static func aesGCMSeal(key: Data, nonce: Data, plaintext: Data, aad: Data) throws -> (ciphertext: Data, tag: Data) {
    let sealed = try AES.GCM.seal(
      plaintext,
      using: SymmetricKey(data: key),
      nonce: AES.GCM.Nonce(data: nonce),
      authenticating: aad
    )
    return (sealed.ciphertext, sealed.tag)
  }

  /// AES-GCM open. `nonce` must be 12 bytes, `tag` 16 bytes.
  public static func aesGCMOpen(key: Data, nonce: Data, ciphertext: Data, tag: Data, aad: Data) throws -> Data {
    let box = try AES.GCM.SealedBox(
      nonce: AES.GCM.Nonce(data: nonce),
      ciphertext: ciphertext,
      tag: tag
    )
    return try AES.GCM.open(box, using: SymmetricKey(data: key), authenticating: aad)
  }
}
