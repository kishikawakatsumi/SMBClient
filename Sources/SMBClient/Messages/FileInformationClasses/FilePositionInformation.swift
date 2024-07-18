import Foundation

public struct FilePositionInformation {
  public let currentByteOffset: UInt64

  public init(data: Data) {
    let byteReader = ByteReader(data)
    currentByteOffset = byteReader.read()
  }
}

extension ByteReader {
  func read() -> FilePositionInformation {
    return FilePositionInformation(data: read(count: 8))
  }
}
