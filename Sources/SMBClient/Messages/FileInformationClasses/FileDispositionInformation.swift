import Foundation

public struct FileDispositionInformation: FileInformationClass {
  public let deletePending: UInt8
  public let infoClass: FileInfoClass = .fileDispositionInformation

  public init(deletePending: Bool) {
    self.deletePending = deletePending ? 1 : 0
  }

  public func encoded() -> Data {
    Data() + deletePending
  }
}
