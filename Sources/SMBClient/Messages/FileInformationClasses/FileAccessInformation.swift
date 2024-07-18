import Foundation

public struct FileAccessInformation {
  public let accessFlags: AccessMask
  
  public init(data: Data) {
    let byteReader = ByteReader(data)
    accessFlags = AccessMask(rawValue: byteReader.read())
  }
}

extension ByteReader {
  func read() -> FileAccessInformation {
    return FileAccessInformation(data: read(count: 4))
  }
}
