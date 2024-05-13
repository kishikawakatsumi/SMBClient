import Foundation
import CommonCrypto

enum Crypto {
  public static func randomBytes(count: Int) -> Data {
    var bytes = [UInt8](repeating: 0, count: count)
    CCRandomGenerateBytes(&bytes, bytes.count)
    return Data(bytes)
  }

  public static func hmacMD5(key: Data, data: Data) -> Data {
    let context = UnsafeMutablePointer<CCHmacContext>.allocate(capacity: 1)
    CCHmacInit(context, CCHmacAlgorithm(kCCHmacAlgMD5), (key as NSData).bytes, size_t(key.count))
    CCHmacUpdate(context, (data as NSData).bytes, size_t(data.count))
    var hmac = Array<UInt8>(repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
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
