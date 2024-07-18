import Foundation

public struct FileNameInformation {
  public let fileNameLength: UInt32
  public let fileName: String

  public init(data: Data) {
    let byteReader = ByteReader(data)
    fileNameLength = byteReader.read()
    let fileNameData = byteReader.read(count: Int(fileNameLength))
    fileName = String(data: fileNameData, encoding: .utf16LittleEndian) ?? fileNameData.hex
  }

  fileprivate init(fileNameLength: UInt32, fileName: String) {
    self.fileNameLength = fileNameLength
    self.fileName = fileName
  }
}

extension ByteReader {
  func read() -> FileNameInformation {
    let fileNameLength: UInt32 = read()
    let fileNameData = read(count: Int(fileNameLength))
    let fileName = String(data: fileNameData, encoding: .utf16LittleEndian) ?? fileNameData.hex
    return FileNameInformation(fileNameLength: fileNameLength, fileName: fileName)
  }
}
