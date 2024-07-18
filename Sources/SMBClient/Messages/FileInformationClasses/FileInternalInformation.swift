import Foundation

public struct FileInternalInformation {
  public let indexNumber: UInt64

  public init(data: Data) {
    let byteReader = ByteReader(data)
    indexNumber = byteReader.read()
  }
}

extension ByteReader {
  func read() -> FileInternalInformation {
    FileInternalInformation(data: read(count: 8))
  }
}
