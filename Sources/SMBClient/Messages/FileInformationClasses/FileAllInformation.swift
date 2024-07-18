import Foundation

public struct FileAllInformation {
  public let basicInformation: FileBasicInformation
  public let standardInformation: FileStandardInformation
  public let internalInformation: FileInternalInformation
  public let eaInformation: FileEaInformation
  public let accessInformation: FileAccessInformation
  public let positionInformation: FilePositionInformation
  public let modeInformation: FileModeInformation
  public let alignmentInformation: FileAlignmentInformation
  public let nameInformation: FileNameInformation

  public init(data: Data) {
    let byteReader = ByteReader(data)
    basicInformation = byteReader.read()
    standardInformation = byteReader.read()
    internalInformation = byteReader.read()
    eaInformation = byteReader.read()
    accessInformation = byteReader.read()
    positionInformation = byteReader.read()
    modeInformation = byteReader.read()
    alignmentInformation = byteReader.read()
    nameInformation = byteReader.read()
  }
}
