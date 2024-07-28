import Foundation

public struct NTStatus {
  public var rawValue: UInt32

  public init(_ rawValue: UInt32) {
    self.rawValue = rawValue
  }
}

extension NTStatus: CustomStringConvertible {
  public var description: String {
    switch ErrorCode(rawValue: rawValue) {
    case .success:
      return "The client request is successful."
    case .pending:
      return "The operation that was requested is pending completion."
    case .invalidSMB:
      return "An invalid SMB client request is received by the server."
    case .smbBadTid:
      return "The client request received by the server contains an invalid TID value."
    case .smbBadCommand:
      return "The client request received by the server contains an unknown SMB command code."
    case .smbBadUID:
      return "The client request to the server contains an invalid UID value."
    case .smbUseStandard:
      return "The client request received by the server is for a non-standard SMB operation (for example, an SMB_COM_READ_MPX request on a non-disk share). The client SHOULD send another request with a different SMB command to perform this operation."
    case .bufferOverflow:
      return "The data was too large to fit into the specified buffer."
    case .noMoreFiles:
      return "No more files were found that match the file specification."
    case .stoppedOnSymlink:
      return "The create operation stopped after reaching a symbolic link."
    case .notImplemented:
      return "The requested operation is not implemented."
    case .invalidInfoClass:
      return "The specified information class is not a valid information class for the specified object."
    case .invalidParameter:
      return "The parameter specified in the request is not valid."
    case .noSuchFile:
      return "File not found."
    case .noSuchDevice:
      return "A device that does not exist was specified."
    case .invalidDeviceRequest:
      return "The specified request is not a valid operation for the target device."
    case .endOfFile:
      return "The end-of-file marker has been reached. There is no valid data in the file beyond this marker."
    case .moreProcessingRequired:
      return "If extended security has been negotiated, then this error code can be returned in the SMB_COM_SESSION_SETUP_ANDX response from the server to indicate that additional authentication information is to be exchanged. See section 2.2.4.6 for details."
    case .accessDenied:
      return "The client did not have the required permission needed for the operation."
    case .bufferTooSmall:
      return "The buffer is too small to contain the entry. No information has been written to the buffer."
    case .objectNameInvalid:
      return "The object name is invalid."
    case .objectNameNotFound:
      return "The object name is not found."
    case .objectNameCollision:
      return "The object name already exists."
    case .sharingViolation:
      return "A file cannot be opened because the share access flags are incompatible."
    case .deletePending:
      return "A non-close operation has been requested of a file object that has a delete pending."
    case .objectPathNotFound:
      return "The path to the directory specified was not found. This error is also returned on a create request if the operation requires the creation of more than one new directory level for the path specified."
    case .logonFailure:
      return "The attempted logon is invalid. This is either due to a bad username or authentication information."
    case .badImpersonationLevel:
      return "A specified impersonation level is invalid. This error is also used to indicate that a required impersonation level was not provided."
    case .ioTimeout:
      return "The specified I/O operation was not completed before the time-out period expired."
    case .fileIsADirectory:
      return "The file that was specified as a target is a directory and the caller specified that it could be anything but a directory."
    case .notSupported:
      return "The client request is not supported."
    case .networkNameDeleted:
      return "The network name specified by the client has been deleted on the server. This error is returned if the client specifies an incorrect TID or the share on the server represented by the TID was deleted."
    case .badNetworkName:
      return "The specified share name cannot be found on the remote server."
    case .notADirectory:
      return "A requested opened file is not a directory."
    case .fileClosed:
      return "An I/O request other than close and several other special case operations was attempted using a file object that had already been closed."
    case .userSessionDeleted:
      return "The user session specified by the client has been deleted on the server. This error is returned by the server if the client sends an incorrect UID."
    case .connectionRefused:
      return "The transport-connection attempt was refused by the remote system."
    case .networkSessionExpired:
      return "The client's session has expired; therefore, the client MUST re-authenticate to continue accessing remote resources."
    case .smbTooManyUIDs:
      return "The client has requested too many UID values from the server or the client already has an SMB session setup with this UID value."
    default:
      return "Unknown error: \(String(format: "0x%08X", rawValue))"
    }
  }
}

extension NTStatus: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch ErrorCode(rawValue: rawValue) {
    case .success:
      return "SUCCESS"
    case .pending:
      return "PENDING"
    case .invalidSMB:
      return "INVALID_SMB"
    case .smbBadTid:
      return "SMB_BAD_TID"
    case .smbBadCommand:
      return "SMB_BAD_COMMAND"
    case .smbBadUID:
      return "SMB_BAD_UID"
    case .smbUseStandard:
      return "SMB_USE_STANDARD"
    case .bufferOverflow:
      return "BUFFER_OVERFLOW"
    case .noMoreFiles:
      return "NO_MORE_FILES"
    case .stoppedOnSymlink:
      return "STOPPED_ON_SYMLINK"
    case .notImplemented:
      return "NOT_IMPLEMENTED"
    case .invalidInfoClass:
      return "INVALID_INFO_CLASS"
    case .invalidParameter:
      return "INVALID_PARAMETER"
    case .noSuchDevice:
      return "NO_SUCH_DEVICE"
    case .noSuchFile:
      return "NO_SUCH_FILE"
    case .invalidDeviceRequest:
      return "INVALID_DEVICE_REQUEST"
    case .endOfFile:  
      return "END_OF_FILE"
    case .moreProcessingRequired: 
      return "MORE_PROCESSING_REQUIRED"
    case .accessDenied:
      return "ACCESS_DENIED"
    case .bufferTooSmall:
      return "BUFFER_TOO_SMALL"
    case .objectNameInvalid:
      return "OBJECT_NAME_INVALID"
    case .objectNameNotFound:
      return "OBJECT_NAME_NOT_FOUND"
    case .objectNameCollision:
      return "OBJECT_NAME_COLLISION"
    case .sharingViolation:
      return "SHARING_VIOLATION"
    case .deletePending:
      return "DELETE_PENDING"
    case .objectPathNotFound: 
      return "OBJECT_PATH_NOT_FOUND"
    case .logonFailure:
      return "LOGON_FAILURE"
    case .badImpersonationLevel:
      return "BAD_IMPERSONATION_LEVEL"
    case .ioTimeout:
      return "IO_TIMEOUT"
    case .fileIsADirectory:
      return "FILE_IS_A_DIRECTORY"
    case .notSupported:
      return "NOT_SUPPORTED"
    case .networkNameDeleted:
      return "NETWORK_NAME_DELETED"
    case .badNetworkName:
      return "BAD_NETWORK_NAME"
    case .notADirectory:
      return "NOT_A_DIRECTORY"
    case .fileClosed:
      return "FILE_CLOSED"
    case .userSessionDeleted:
      return "USER_SESSION_DELETED"
    case .connectionRefused:
      return "CONNECTION_REFUSED"
    case .networkSessionExpired:
      return "NETWORK_SESSION_EXPIRED"
    case .smbTooManyUIDs:
      return "SMB_TOO_MANY_UIDS"
    default:
      return "UNKNOWN_ERROR"
    }
  }
}

public enum ErrorCode: UInt32 {
  case success = 0x00000000
  case pending = 0x00000103
  case invalidSMB = 0x00010002
  case smbBadTid = 0x00050002
  case smbBadCommand = 0x00160002
  case smbBadUID = 0x005B0002
  case smbUseStandard = 0x00FB0002
  case bufferOverflow = 0x80000005
  case noMoreFiles = 0x80000006
  case stoppedOnSymlink = 0x8000002D
  case notImplemented = 0xC0000002
  case invalidInfoClass = 0xC000000
  case invalidParameter = 0xC000000D
  case noSuchDevice = 0xC000000E
  case noSuchFile = 0xC000000F
  case invalidDeviceRequest = 0xC0000010
  case endOfFile = 0xC0000011
  case moreProcessingRequired = 0xC0000016
  case accessDenied = 0xC0000022
  case bufferTooSmall = 0xC0000023
  case objectNameInvalid = 0xC0000033
  case objectNameNotFound = 0xC0000034
  case objectNameCollision = 0xC0000035
  case sharingViolation = 0xC0000043
  case deletePending = 0xC0000056
  case objectPathNotFound = 0xC000003A
  case logonFailure = 0xC000006D
  case badImpersonationLevel = 0xC00000A5
  case ioTimeout = 0xC00000B5
  case fileIsADirectory = 0xC00000BA
  case notSupported = 0xC00000BB
  case networkNameDeleted = 0xC00000C9
  case badNetworkName = 0xC00000CC
  case notADirectory = 0xC0000103
  case fileClosed = 0xC0000128
  case userSessionDeleted = 0xC0000203
  case connectionRefused = 0xC0000236
  case networkSessionExpired = 0xC000035C
  case smbTooManyUIDs = 0xC000205A
}

public func ==(lhs: NTStatus, rhs: ErrorCode) -> Bool {
  return lhs.rawValue == rhs.rawValue
}

public func ==(lhs: ErrorCode, rhs: NTStatus) -> Bool {
  return lhs.rawValue == rhs.rawValue
}

public func !=(lhs: NTStatus, rhs: ErrorCode) -> Bool {
  return lhs.rawValue != rhs.rawValue
}

public func !=(lhs: ErrorCode, rhs: NTStatus) -> Bool {
  return lhs.rawValue != rhs.rawValue
}

public func ~=(pattern: ErrorCode, value: NTStatus) -> Bool {
  return pattern.rawValue == value.rawValue
}
