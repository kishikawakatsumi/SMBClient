import Foundation

public enum FileInfoClass: UInt8 {
  case fileAccessInformation = 0x08
  case fileAlignmentInformation = 0x11
  case fileAllInformation = 0x12
  case fileAllocationInformation = 0x13
  case fileAlternateNameInformation = 0x15
  case fileAttributeTagInformation = 0x23
  case fileBasicInformation = 0x04
  case fileBothDirectoryInformation = 0x03
  case fileCompressionInformation = 0x1C
  case fileDirectoryInformation = 0x01
  case fileDispositionInformation = 0x0D
  case fileEaInformation = 0x07
  case fileEndOfFileInformation = 0x14
  case fileFullDirectoryInformation = 0x02
  case fileFullEaInformation = 0x0F
  case fileHardLinkInformation = 0x2E
  case fileIdBothDirectoryInformation = 0x25
  case fileIdExtdDirectoryInformation = 0x3C
  case fileIdFullDirectoryInformation = 0x26
  case fileIdGlobalTxDirectoryInformation = 0x32
  case fileIdInformation = 0x3B
  case fileInternalInformation = 0x06
  case fileLinkInformation = 0x0B
  case fileMailslotQueryInformation = 0x1A
  case fileMailslotSetInformation = 0x1B
  case fileModeInformation = 0x10
  case fileMoveClusterInformation = 0x1F
  case fileNameInformation = 0x09
  case fileNamesInformation = 0x0C
  case fileNetworkOpenInformation = 0x22
  case fileNormalizedNameInformation = 0x30
  case fileObjectIdInformation = 0x1D
  case filePipeInformation = 0x17
  case filePipeLocalInformation = 0x18
  case filePipeRemoteInformation = 0x19
  case filePositionInformation = 0x0E
  case fileQuotaInformation = 0x20
  case fileRenameInformation = 0x0A
  case fileReparsePointInformation = 0x21
  case fileSfioReserveInformation = 0x2C
  case fileSfioVolumeInformation = 0x2D
  case fileShortNameInformation = 0x28
  case fileStandardInformation = 0x05
  case fileStandardLinkInformation = 0x36
  case fileStreamInformation = 0x16
  case fileTrackingInformation = 0x24
  case fileValidDataLengthInformation = 0x27

  static let fileFsVolumeInformation = fileDirectoryInformation
  static let fileFsLabelInformation = fileFullDirectoryInformation
  static let fileFsSizeInformation = fileBothDirectoryInformation
  static let fileFsDeviceInformation = fileBasicInformation
  static let fileFsAttributeInformation = fileStandardInformation
  static let fileFsControlInformation = fileInternalInformation
  static let fileFsFullSizeInformation = fileEaInformation
  static let fileFsObjectIdInformation = fileAccessInformation
  static let fileFsDriverPathInformation = fileNameInformation
  static let fileFsVolumeFlagsInformation = fileModeInformation
  static let fileFsSectorSizeInformation: FileInfoClass = fileAlignmentInformation
}

extension FileInfoClass: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .fileAccessInformation: return "SMB2_FILE_ACCESS_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileAlignmentInformation: return "SMB2_FILE_ALIGNMENT_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileAllInformation: return "SMB2_FILE_ALL_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileAllocationInformation: return "SMB2_FILE_ALLOCATION_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileAlternateNameInformation: return "SMB2_FILE_ALTERNATE_NAME_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileAttributeTagInformation: return "SMB2_FILE_ATTRIBUTE_TAG_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileBasicInformation: return "SMB2_FILE_BASIC_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileBothDirectoryInformation: return "SMB2_FILE_BOTH_DIRECTORY_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileCompressionInformation: return "SMB2_FILE_COMPRESSION_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileDirectoryInformation: return "SMB2_FILE_DIRECTORY_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileDispositionInformation: return "SMB2_FILE_DISPOSITION_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileEaInformation: return "SMB2_FILE_EA_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileEndOfFileInformation: return "SMB2_FILE_ENDOFFILE_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileFullDirectoryInformation: return "SMB2_FILE_FULL_DIRECTORY_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileFullEaInformation: return "SMB2_FILE_FULL_EA_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileHardLinkInformation: return "SMB2_FILE_HARD_LINK_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileIdBothDirectoryInformation: return "SMB2_FILE_ID_BOTH_DIRECTORY_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileIdExtdDirectoryInformation: return "SMB2_FILE_ID_EXTD_DIRECTORY_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileIdFullDirectoryInformation: return "SMB2_FILE_ID_FULL_DIRECTORY_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileIdGlobalTxDirectoryInformation: return "SMB2_FILE_ID_GLOBAL_TX_DIRECTORY_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileIdInformation: return "SMB2_FILE_ID_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileInternalInformation: return "SMB2_FILE_INTERNAL_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileLinkInformation: return "SMB2_FILE_LINK_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileMailslotQueryInformation: return "SMB2_FILE_MAIL_SLOT_QUERY_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileMailslotSetInformation: return "SMB2_FILE_MAIL_SLOT_SET_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileModeInformation: return "SMB2_FILE_MODE_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileMoveClusterInformation: return "SMB2_FILE_MOVE_CLUSTER_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileNameInformation: return "SMB2_FILE_NAME_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileNamesInformation: return "SMB2_FILE_NAMES_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileNetworkOpenInformation: return "SMB2_FILE_NETWORK_OPEN_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileNormalizedNameInformation: return "SMB2_FILE_NORMALIZED_NAME_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileObjectIdInformation: return "SMB2_FILE_OBJECTID_INFO (\(String(format: "0x%02x", rawValue)))"
    case .filePipeInformation: return "SMB2_FILE_PIPE_INFO (\(String(format: "0x%02x", rawValue)))"
    case .filePipeLocalInformation: return "SMB2_FILE_PIPE_LOCAL_INFO (\(String(format: "0x%02x", rawValue)))"
    case .filePipeRemoteInformation: return "SMB2_FILE_PIPE_REMOTE_INFO (\(String(format: "0x%02x", rawValue)))"
    case .filePositionInformation: return "SMB2_FILE_POSITION_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileQuotaInformation: return "SMB2_FILE_QUOTA_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileRenameInformation: return "SMB2_FILE_RENAME_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileReparsePointInformation: return "SMB2_FILE_REPARSE_POINT_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileSfioReserveInformation: return "SMB2_FILE_SFIO_RESERVE_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileSfioVolumeInformation: return "SMB2_FILE_SFIO_VOLUME_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileShortNameInformation: return "SMB2_FILE_SHORT_NAME_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileStandardInformation: return "SMB2_FILE_STANDARD_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileStandardLinkInformation: return "SMB2_FILE_STANDARD_LINK_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileStreamInformation: return "SMB2_FILE_STREAM_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileTrackingInformation: return "SMB2_FILE_TRACKING_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileValidDataLengthInformation: return "SMB2_FILE_VALID_DATA_LENGTH_INFO (\(String(format: "0x%02x", rawValue)))"
    }
  }
}
