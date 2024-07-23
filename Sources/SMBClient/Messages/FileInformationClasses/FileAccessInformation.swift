import Foundation

public struct FileAccessInformation {
  public let accessFlags: AccessMask

  public init(data: Data) {
    let reader = ByteReader(data)
    accessFlags = AccessMask(rawValue: reader.read())
  }
}

extension ByteReader {
  func read() -> FileAccessInformation {
    FileAccessInformation(data: read(count: 4))
  }
}
