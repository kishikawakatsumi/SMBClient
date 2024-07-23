import Foundation

public struct FilePositionInformation {
  public let currentByteOffset: UInt64

  public init(data: Data) {
    let reader = ByteReader(data)
    currentByteOffset = reader.read()
  }
}

extension ByteReader {
  func read() -> FilePositionInformation {
    return FilePositionInformation(data: read(count: 8))
  }
}
