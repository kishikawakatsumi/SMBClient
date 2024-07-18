import Foundation

public struct FileNameInformation {
  public let fileNameLength: UInt32
  public let fileName: String

  public init(data: Data) {
    let byteReader = ByteReader(data)
    fileNameLength = byteReader.read()
    fileName = String(data: byteReader.read(count: Int(fileNameLength)), encoding: .utf16LittleEndian)!
  }

  fileprivate init(fileNameLength: UInt32, fileName: String) {
    self.fileNameLength = fileNameLength
    self.fileName = fileName
  }
}

extension ByteReader {
  func read() -> FileNameInformation {
    let fileNameLength: UInt32 = read()
    let fileName = String(data: read(count: Int(fileNameLength)), encoding: .utf16LittleEndian)!
    return FileNameInformation(fileNameLength: fileNameLength, fileName: fileName)
  }
}
