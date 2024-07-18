import Foundation

public struct FileBasicInformation {
  public let creationTime: UInt64
  public let lastAccessTime: UInt64
  public let lastWriteTime: UInt64
  public let changeTime: UInt64
  public let fileAttributes: FileAttributes
  public let reserved: UInt32

  public init(data: Data) {
    let byteReader = ByteReader(data)
    creationTime = byteReader.read()
    lastAccessTime = byteReader.read()
    lastWriteTime = byteReader.read()
    changeTime = byteReader.read()
    fileAttributes = FileAttributes(rawValue: byteReader.read())
    reserved = byteReader.read()
  }
}

extension ByteReader {
  func read() -> FileBasicInformation {
    return FileBasicInformation(data: read(count: 40))
  }
}
