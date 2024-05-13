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

extension String: BinaryConvertible {
  static func +(lhs: Data, rhs: Self) -> Data {
    return lhs + (rhs.data(using: .utf16LittleEndian) ?? Data())
  }

  static func +=(lhs: inout Data, rhs: Self) {
    lhs = lhs + rhs
  }
}
