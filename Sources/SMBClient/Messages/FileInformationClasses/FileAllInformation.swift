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
    let reader = ByteReader(data)

    basicInformation = reader.read()
    standardInformation = reader.read()
    internalInformation = reader.read()
    eaInformation = reader.read()
    accessInformation = reader.read()
    positionInformation = reader.read()
    modeInformation = reader.read()
    alignmentInformation = reader.read()
    nameInformation = reader.read()
  }
}
