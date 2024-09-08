import Foundation

public struct FileDirectoryInformation {
  public let nextEntryOffset: UInt32
  public let fileIndex: UInt32
  public let creationTime: UInt64
  public let lastAccessTime: UInt64
  public let lastWriteTime: UInt64
  public let changeTime: UInt64
  public let endOfFile: UInt64
  public let allocationSize: UInt64
  public let fileAttributes: FileAttributes
  public let fileNameLength: UInt32
  public let fileName: String

  public init(data: Data) {
    let reader = ByteReader(data)

    nextEntryOffset = reader.read()
    fileIndex = reader.read()
    creationTime = reader.read()
    lastAccessTime = reader.read()
    lastWriteTime = reader.read()
    changeTime = reader.read()
    endOfFile = reader.read()
    allocationSize = reader.read()
    fileAttributes = FileAttributes(rawValue: reader.read())
    fileNameLength = reader.read()

    let fileNameData = reader.read(count: Int(fileNameLength))
    fileName = String(data: fileNameData, encoding: .utf16LittleEndian) ?? fileNameData.hex
  }
}
