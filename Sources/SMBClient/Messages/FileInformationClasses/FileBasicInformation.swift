import Foundation

public struct FileBasicInformation {
  public let creationTime: UInt64
  public let lastAccessTime: UInt64
  public let lastWriteTime: UInt64
  public let changeTime: UInt64
  public let fileAttributes: FileAttributes
  public let reserved: UInt32

  public init(data: Data) {
    let reader = ByteReader(data)
    
    creationTime = reader.read()
    lastAccessTime = reader.read()
    lastWriteTime = reader.read()
    changeTime = reader.read()
    fileAttributes = FileAttributes(rawValue: reader.read())
    reserved = reader.read()
  }
}

extension ByteReader {
  func read() -> FileBasicInformation {
    FileBasicInformation(data: read(count: 40))
  }
}
