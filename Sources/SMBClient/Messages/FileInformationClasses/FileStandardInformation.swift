import Foundation

public struct FileStandardInformation {
  public let allocationSize: UInt64
  public let endOfFile: UInt64
  public let numberOfLinks: UInt32
  public let deletePending: Bool
  public let directory: Bool
  public let reserved: UInt16

  public init(data: Data) {
    let reader = ByteReader(data)

    allocationSize = reader.read()
    endOfFile = reader.read()
    numberOfLinks = reader.read()
    deletePending = reader.read()
    directory = reader.read()
    reserved = reader.read()
  }
}

extension ByteReader {
  func read() -> FileStandardInformation {
    FileStandardInformation(data: read(count: 24))
  }
}
