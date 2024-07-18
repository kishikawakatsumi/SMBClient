import Foundation

public struct FileEaInformation {
  public let eaSize: UInt32

  public init(data: Data) {
    let byteReader = ByteReader(data)
    eaSize = byteReader.read()
  }
}

extension ByteReader {
  func read() -> FileEaInformation {
    return FileEaInformation(data: read(count: 4))
  }
}
