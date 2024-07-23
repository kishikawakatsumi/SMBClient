import Foundation

public struct FileInternalInformation {
  public let indexNumber: UInt64

  public init(data: Data) {
    let reader = ByteReader(data)
    indexNumber = reader.read()
  }
}

extension ByteReader {
  func read() -> FileInternalInformation {
    FileInternalInformation(data: read(count: 8))
  }
}
