import Foundation

public struct FileStandardInformation {
  public let allocationSize: UInt64
  public let endOfFile: UInt64
  public let numberOfLinks: UInt32
  public let deletePending: Bool
  public let directory: Bool
  public let reserved: UInt16

  public init(data: Data) {
    let byteReader = ByteReader(data)
    allocationSize = byteReader.read()
    endOfFile = byteReader.read()
    numberOfLinks = byteReader.read()
    deletePending = byteReader.read()
    directory = byteReader.read()
    reserved = byteReader.read()
  }
}

extension ByteReader {
  func read() -> FileStandardInformation {
    FileStandardInformation(data: read(count: 24))
  }
}
