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

extension FileDispositionInformation: CustomStringConvertible {
  public var description: String {
    "SMB2_FILE_DISPOSITION_INFO: Delete on close: \(deletePending == 1 ? "DELETE this file when closed" : "Normal access, do not delete on close")"
  }
}
