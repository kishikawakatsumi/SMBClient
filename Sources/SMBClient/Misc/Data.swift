import Foundation

protocol BinaryConvertible {
  static func +(lhs: Data, rhs: Self) -> Data
  static func +=(lhs: inout Data, rhs: Self)
}

extension BinaryConvertible {
  static func +(lhs: Data, rhs: Self) -> Data {
    var value = rhs
    return lhs + withUnsafeBytes(of: &value) { Data($0) }
  }

  static func +=(lhs: inout Data, rhs: Self) {
    lhs = lhs + rhs
  }
}

extension UInt8: BinaryConvertible {}
extension UInt16: BinaryConvertible {}
extension UInt32: BinaryConvertible {}
extension UInt64: BinaryConvertible {}
extension Int8: BinaryConvertible {}
extension Int16: BinaryConvertible {}
extension Int32: BinaryConvertible {}
extension Int64: BinaryConvertible {}
extension Int: BinaryConvertible {}

extension Data {
  init?(_ hex: String) {
    let len = hex.count / 2
    var data = Data(capacity: len)
    for i in 0..<len {
      let j = hex.index(hex.startIndex, offsetBy: i * 2)
      let k = hex.index(j, offsetBy: 2)
      let bytes = hex[j..<k]
      if var num = UInt8(bytes, radix: 16) {
        data.append(&num, count: 1)
      } else {
        return nil
      }
    }
    self = data
  }

  var hex: String {
    return reduce("") { $0 + String(format: "%02x", $1) }
  }
}
