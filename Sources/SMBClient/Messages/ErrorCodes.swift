import Foundation

public typealias NTStatus = ErrorCodes

public enum ErrorCodes {
  public static let success: UInt32 = 0x00000000
  public static let pending: UInt32 = 0x00000103
  public static let invalidSMB: UInt32 = 0x00010002
  public static let smbBadTid: UInt32 = 0x00050002
  public static let smbBadCommand: UInt32 = 0x00160002
  public static let smbBadUID: UInt32 = 0x005B0002
  public static let smbUseStandard: UInt32 = 0x00FB0002
  public static let bufferOverflow: UInt32 = 0x80000005
  public static let noMoreFiles: UInt32 = 0x80000006
  public static let stoppedOnSymlink: UInt32 = 0x8000002D
  public static let notImplemented: UInt32 = 0xC0000002
  public static let invalidParameter: UInt32 = 0xC000000D
  public static let noSuchDevice: UInt32 = 0xC000000E
  public static let noSuchFile: UInt32 = 0xC000000F
  public static let invalidDeviceRequest: UInt32 = 0xC0000010
  public static let endOfFile: UInt32 = 0xC0000011
  public static let moreProcessingRequired: UInt32 = 0xC0000016
  public static let accessDenied: UInt32 = 0xC0000022
  public static let bufferTooSmall: UInt32 = 0xC0000023
  public static let objectNameInvalid: UInt32 = 0xC0000033
  public static let objectNameNotFound: UInt32 = 0xC0000034
  public static let objectNameCollision: UInt32 = 0xC0000035
  public static let sharingViolation: UInt32 = 0xC0000043
  public static let deletePending: UInt32 = 0xC0000056
  public static let objectPathNotFound: UInt32 = 0xC000003A
  public static let logonFailure: UInt32 = 0xC000006D
  public static let badImpersonationLevel: UInt32 = 0xC00000A5
  public static let ioTimeout: UInt32 = 0xC00000B5
  public static let fileIsADirectory: UInt32 = 0xC00000BA
  public static let notSupported: UInt32 = 0xC00000BB
  public static let networkNameDeleted: UInt32 = 0xC00000C9
  public static let fileClosed: UInt32 = 0xC0000128
  public static let userSessionDeleted: UInt32 = 0xC0000203
  public static let networkSessionExpired: UInt32 = 0xC000035C
  public static let smbTooManyUIDs: UInt32 = 0xC000205A

  public static func description(_ code: UInt32) -> String {
    switch code {
    case ErrorCodes.success:
      return "The client request is successful."
    case ErrorCodes.pending:
      return "The operation that was requested is pending completion."
    case ErrorCodes.invalidSMB:
      return "An invalid SMB client request is received by the server."
    case ErrorCodes.smbBadTid:
      return "The client request received by the server contains an invalid TID value."
    case ErrorCodes.smbBadCommand:
      return "The client request received by the server contains an unknown SMB command code."
    case ErrorCodes.smbBadUID:
      return "The client request to the server contains an invalid UID value."
    case ErrorCodes.smbUseStandard:
      return "The client request received by the server is for a non-standard SMB operation (for example, an SMB_COM_READ_MPX request on a non-disk share). The client SHOULD send another request with a different SMB command to perform this operation."
    case ErrorCodes.bufferOverflow:
      return "The data was too large to fit into the specified buffer."
    case ErrorCodes.noMoreFiles:
      return "No more files were found that match the file specification."
    case ErrorCodes.stoppedOnSymlink:
      return "The create operation stopped after reaching a symbolic link."
    case ErrorCodes.notImplemented:
      return "The requested operation is not implemented."
    case ErrorCodes.invalidParameter:
      return "The parameter specified in the request is not valid."
    case ErrorCodes.noSuchFile:
      return "File not found."
    case ErrorCodes.noSuchDevice:
      return "A device that does not exist was specified."
    case ErrorCodes.invalidDeviceRequest:
      return "The specified request is not a valid operation for the target device."
    case ErrorCodes.endOfFile:
      return "The end-of-file marker has been reached. There is no valid data in the file beyond this marker."
    case ErrorCodes.moreProcessingRequired:
      return "If extended security has been negotiated, then this error code can be returned in the SMB_COM_SESSION_SETUP_ANDX response from the server to indicate that additional authentication information is to be exchanged. See section 2.2.4.6 for details."
    case ErrorCodes.accessDenied:
      return "The client did not have the required permission needed for the operation."
    case ErrorCodes.bufferTooSmall:
      return "The buffer is too small to contain the entry. No information has been written to the buffer."
    case ErrorCodes.objectNameInvalid:
      return "The object name is invalid."
    case ErrorCodes.objectNameNotFound:
      return "The object name is not found."
    case ErrorCodes.objectNameCollision:
      return "The object name already exists."
    case ErrorCodes.sharingViolation:
      return "A file cannot be opened because the share access flags are incompatible."
    case ErrorCodes.deletePending:
      return "A non-close operation has been requested of a file object that has a delete pending."
    case ErrorCodes.objectPathNotFound:
      return "The path to the directory specified was not found. This error is also returned on a create request if the operation requires the creation of more than one new directory level for the path specified."
    case ErrorCodes.logonFailure:
      return "The attempted logon is invalid. This is either due to a bad username or authentication information."
    case ErrorCodes.badImpersonationLevel:
      return "A specified impersonation level is invalid. This error is also used to indicate that a required impersonation level was not provided."
    case ErrorCodes.ioTimeout:
      return "The specified I/O operation was not completed before the time-out period expired."
    case ErrorCodes.fileIsADirectory:
      return "The file that was specified as a target is a directory and the caller specified that it could be anything but a directory."
    case ErrorCodes.notSupported:
      return "The client request is not supported."
    case ErrorCodes.networkNameDeleted:
      return "The network name specified by the client has been deleted on the server. This error is returned if the client specifies an incorrect TID or the share on the server represented by the TID was deleted."
    case ErrorCodes.fileClosed:
      return "An I/O request other than close and several other special case operations was attempted using a file object that had already been closed."
    case ErrorCodes.userSessionDeleted:
      return "The user session specified by the client has been deleted on the server. This error is returned by the server if the client sends an incorrect UID."
    case ErrorCodes.networkSessionExpired:
      return "The client's session has expired; therefore, the client MUST re-authenticate to continue accessing remote resources."
    case ErrorCodes.smbTooManyUIDs:
      return "The client has requested too many UID values from the server or the client already has an SMB session setup with this UID value."
    default:
      return "Unknown error: \(String(format: "0x%08X", code))"
    }
  }
}
