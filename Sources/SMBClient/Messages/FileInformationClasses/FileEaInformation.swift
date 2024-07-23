import Foundation

public struct FileEaInformation {
  public let eaSize: UInt32

  public init(data: Data) {
    let reader = ByteReader(data)
    eaSize = reader.read()
  }
}

extension ByteReader {
  func read() -> FileEaInformation {
    FileEaInformation(data: read(count: 4))
  }
}
