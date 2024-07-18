import Foundation

public struct DirectoryAccessMask: OptionSet {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let listDirectory = DirectoryAccessMask(rawValue: 0x00000001)
  public static let addFile = DirectoryAccessMask(rawValue: 0x00000002)
  public static let addSubdirectory = DirectoryAccessMask(rawValue: 0x00000004)
  public static let readEa = DirectoryAccessMask(rawValue: 0x00000008)
  public static let writeEa = DirectoryAccessMask(rawValue: 0x00000010)
  public static let traverse = DirectoryAccessMask(rawValue: 0x00000020)
  public static let deleteChild = DirectoryAccessMask(rawValue: 0x00000040)
  public static let readAttributes = DirectoryAccessMask(rawValue: 0x00000080)
  public static let writeAttributes = DirectoryAccessMask(rawValue: 0x00000100)
  public static let delete = DirectoryAccessMask(rawValue: 0x00010000)
  public static let readControl = DirectoryAccessMask(rawValue: 0x00020000)
  public static let writeDac = DirectoryAccessMask(rawValue: 0x00040000)
  public static let writeOwner = DirectoryAccessMask(rawValue: 0x00080000)
  public static let synchronize = DirectoryAccessMask(rawValue: 0x00100000)
  public static let accessSystemSecurity = DirectoryAccessMask(rawValue: 0x01000000)
  public static let maximumAllowed = DirectoryAccessMask(rawValue: 0x02000000)
  public static let genericAll = DirectoryAccessMask(rawValue: 0x10000000)
  public static let genericExecute = DirectoryAccessMask(rawValue: 0x20000000)
  public static let genericWrite = DirectoryAccessMask(rawValue: 0x40000000)
  public static let genericRead = DirectoryAccessMask(rawValue: 0x80000000)
}
