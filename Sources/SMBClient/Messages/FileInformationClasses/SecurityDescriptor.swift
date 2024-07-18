import Foundation

public struct SecurityDescriptor: OptionSet, Sendable {
  public let rawValue: UInt8

  public init(rawValue: UInt8) {
    self.rawValue = rawValue
  }

  public static let owner = SecurityDescriptor(rawValue: 0x00000001)
  public static let group = SecurityDescriptor(rawValue: 0x00000002)
  public static let dacl = SecurityDescriptor(rawValue: 0x00000004)
  public static let sacl = SecurityDescriptor(rawValue: 0x00000008)
  public static let label = SecurityDescriptor(rawValue: 0x00000010)
  public static let attribute = SecurityDescriptor(rawValue: 0x00000020)
  public static let scope = SecurityDescriptor(rawValue: 0x00000040)
  public static let backup = SecurityDescriptor(rawValue: 0x00000080)
}
