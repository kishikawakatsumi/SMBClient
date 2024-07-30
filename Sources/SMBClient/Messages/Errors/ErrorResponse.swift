import Foundation

public struct ErrorResponse: Error {
  public let header: Header
  public let structureSize: UInt16
  public let errorContextCount: UInt8
  public let reserved: UInt8

  public init(data: Data) {
    let reader = ByteReader(data)

    header = reader.read()
    structureSize = reader.read()
    errorContextCount = reader.read()
    reserved = reader.read()
  }
}

extension ErrorResponse: CustomStringConvertible {
  public var description: String {
    return NTStatus(header.status).description
  }
}

extension ErrorResponse: LocalizedError {
  public var errorDescription: String? {
    switch NTStatus(header.status) {
    case .success:
      return "Success"
    case .pending:
      return "Pending"
    case .invalidSMB:
      return "Invalid SMB"
    case .smbBadTid:
      return "Bad TID"
    case .smbBadCommand:
      return "Bad Command"
    case .smbBadUID:
      return "Bad UID"
    case .smbUseStandard:
      return "Use Standard"
    case .bufferOverflow:
      return "Buffer Overflow"
    case .noMoreFiles:
      return "No More Files"
    case .stoppedOnSymlink:
      return "Stopped on Symlink"
    case .notImplemented:
      return "Not Implemented"
    case .invalidInfoClass:
      return "Invalid Info Class"
    case .invalidParameter:
      return "Invalid Parameter"
    case .noSuchDevice:
      return "No Such Device"
    case .noSuchFile:
      return "No Such File"
    case .invalidDeviceRequest:
      return "Invalid Device Request"
    case .endOfFile:
      return "End of File"
    case .moreProcessingRequired:
      return "More Processing Required"
    case .accessDenied:
      return "Access Denied"
    case .bufferTooSmall:
      return "Buffer Too Small"
    case .objectNameInvalid:
      return "Object Name Invalid"
    case .objectNameNotFound:
      return "Object Name Not Found"
    case .objectNameCollision:
      return "Object Name Collision"
    case .sharingViolation:
      return "Sharing Violation"
    case .deletePending:
      return "Delete Pending"
    case .objectPathNotFound:
      return "Object Path Not Found"
    case .logonFailure:
      return "Logon Failure"
    case .badImpersonationLevel:
      return "Bad Impersonation Level"
    case .ioTimeout:
      return "IO Timeout"
    case .fileIsADirectory:
      return "File is a Directory"
    case .notSupported:
      return "Not Supported"
    case .networkNameDeleted:
      return "Network Name Deleted"
    case .badNetworkName:
      return "Bad Network Name"
    case .notADirectory:
      return "Not a Directory"
    case .fileClosed:
      return "File Closed"
    case .userSessionDeleted:
      return "User Session Deleted"
    case .connectionRefused:
      return "Connection Refused"
    case .networkSessionExpired:
      return "Network Session Expired"
    case .smbTooManyUIDs:
      return "Too Many UIDs"
    default:
      return "Unknown error"
    }
  }

  public var failureReason: String? {
    return description
  }

  public var recoverySuggestion: String? {
    return description
  }
}
