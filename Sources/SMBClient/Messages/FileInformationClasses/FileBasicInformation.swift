import Foundation

public struct FileBasicInformation: FileInformationClass {
  public let creationTime: UInt64
  public let lastAccessTime: UInt64
  public let lastWriteTime: UInt64
  public let changeTime: UInt64
  public let fileAttributes: FileAttributes
  public let reserved: UInt32

  public var infoClass: FileInfoClass { .fileBasicInformation }

  init(
    creationTime: UInt64,
    lastAccessTime: UInt64,
    lastWriteTime: UInt64,
    changeTime: UInt64,
    fileAttributes: FileAttributes
  ) {
    self.creationTime = creationTime
    self.lastAccessTime = lastAccessTime
    self.lastWriteTime = lastWriteTime
    self.changeTime = changeTime
    self.fileAttributes = fileAttributes
    reserved = 0
  }

  public init(data: Data) {
    let reader = ByteReader(data)
    
    creationTime = reader.read()
    lastAccessTime = reader.read()
    lastWriteTime = reader.read()
    changeTime = reader.read()
    fileAttributes = FileAttributes(rawValue: reader.read())
    reserved = reader.read()
  }

  public func encoded() -> Data {
    var data = Data()

    data += creationTime
    data += lastAccessTime
    data += lastWriteTime
    data += changeTime
    data += fileAttributes.rawValue
    data += reserved

    return data
  }
}

extension ByteReader {
  func read() -> FileBasicInformation {
    FileBasicInformation(data: read(count: 40))
  }
}
