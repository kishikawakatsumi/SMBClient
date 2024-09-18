import Foundation
import CommonCrypto

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
    CCHmacInit(context, CCHmacAlgorithm(kCCHmacAlgMD5), (key as NSData).bytes, size_t(key.count))
    CCHmacUpdate(context, (data as NSData).bytes, size_t(data.count))
    var hmac = Array<UInt8>(repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
    CCHmacFinal(context, &hmac)
    return Data(hmac)
  }

  public static func hmacSHA256(key: Data, data: Data) -> Data {
    let context = UnsafeMutablePointer<CCHmacContext>.allocate(capacity: 1)
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
}
