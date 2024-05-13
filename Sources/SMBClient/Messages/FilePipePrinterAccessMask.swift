import Foundation

public struct FilePipePrinterAccessMask: OptionSet {
  public let rawValue: UInt32

  public init(rawValue: UInt32) {
    self.rawValue = rawValue
  }

  public static let readData = FilePipePrinterAccessMask(rawValue: 0x00000001)
  public static let writeData = FilePipePrinterAccessMask(rawValue: 0x00000002)
  public static let appendData = FilePipePrinterAccessMask(rawValue: 0x00000004)
  public static let readEa = FilePipePrinterAccessMask(rawValue: 0x00000008)
  public static let writeEa = FilePipePrinterAccessMask(rawValue: 0x00000010)
  public static let deleteChild = FilePipePrinterAccessMask(rawValue: 0x00000040)
  public static let execute = FilePipePrinterAccessMask(rawValue: 0x00000020)
  public static let readAttributes = FilePipePrinterAccessMask(rawValue: 0x00000080)
  public static let writeAttributes = FilePipePrinterAccessMask(rawValue: 0x00000100)
  public static let delete = FilePipePrinterAccessMask(rawValue: 0x00010000)
  public static let readControl = FilePipePrinterAccessMask(rawValue: 0x00020000)
  public static let writeDac = FilePipePrinterAccessMask(rawValue: 0x00040000)
  public static let writeOwner = FilePipePrinterAccessMask(rawValue: 0x00080000)
  public static let synchronize = FilePipePrinterAccessMask(rawValue: 0x00100000)
  public static let accessSystemSecurity = FilePipePrinterAccessMask(rawValue: 0x01000000)
  public static let maximumAllowed = FilePipePrinterAccessMask(rawValue: 0x02000000)
  public static let genericAll = FilePipePrinterAccessMask(rawValue: 0x10000000)
  public static let genericExecute = FilePipePrinterAccessMask(rawValue: 0x20000000)
  public static let genericWrite = FilePipePrinterAccessMask(rawValue: 0x40000000)
  public static let genericRead = FilePipePrinterAccessMask(rawValue: 0x80000000)
}
