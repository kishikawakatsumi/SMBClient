import Foundation

public struct FileRenameInformation: FileInformationClass {
  public let replaceIfExists: Data
  public let reserved: Data
  public let rootDirectory: UInt64
  public let fileNameLength: UInt32
  public let fileName: Data

  public var infoClass: FileInfoClass { .fileRenameInformation }

  public init(replaceIfExists: Bool = false, fileName: String) {
    self.replaceIfExists = replaceIfExists ? Data(repeating: 0x01, count: 1) : Data(repeating: 0x00, count: 1)
    reserved = Data(count: 7)
    rootDirectory = 0
    let fileNameData = fileName.data(using: .utf16LittleEndian)!
    fileNameLength = UInt32(truncatingIfNeeded: fileNameData.count)
    self.fileName = fileNameData
  }

  public func encoded() -> Data {
    var data = Data()

    data += replaceIfExists
    data += reserved
    data += rootDirectory
    data += fileNameLength
    data += fileName

    let padding = 24 - data.count
    if padding > 0 {
      data += Data(count: padding)
    }

    return data
  }
}
