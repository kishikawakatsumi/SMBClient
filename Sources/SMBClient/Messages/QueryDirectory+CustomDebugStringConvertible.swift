import Foundation

extension QueryDirectory.Request: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Find Request (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Info Level: \(fileInformationClass)
      Find Flags: \(flags)
      File Index: \(String(format: "0x%08x", fileIndex))
      GUID handle File: \(UUID(data: fileId))
      Blob Offset: \(fileNameOffset)
      Blob Length: \(fileNameLength)
      Output Buffer Length: \(outputBufferLength)
      Search Pattern: \(String(data: buffer, encoding: .utf16LittleEndian) ?? buffer.hex)
    """
  }
}

extension QueryDirectory.Response: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Find Response (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Blob Offset: \(outputBufferOffset)
      Blob Length: \(outputBufferLength)
      Info:
    \(files.map { "\($0)".split(separator: "\n").map { "  \($0)" }.joined(separator: "\n") }.joined(separator: "\n"))
    """
  }
}

extension QueryDirectory.FileInformationClass: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .fileDirectoryInformation:
      return "SMB2_FILE_DIRECTORY_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileFullDirectoryInformation:
      return "SMB2_FILE_FULL_DIRECTORY_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileIdFullDirectoryInformation:
      return "SMB2_FILE_ID_FULL_DIRECTORY_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileBothDirectoryInformation:
      return "SMB2_FILE_BOTH_DIRECTORY_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileIdBothDirectoryInformation:
      return "SMB2_FILE_ID_BOTH_DIRECTORY_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileNamesInformation:
      return "SMB2_FILE_NAME_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileIdExtdDirectoryInformation:
      return "SMB2_FILE_ID_EXTD_DIRECTORY_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileInfomationClass_Reserved:
      return "SMB2_FILE_INFORMATION_CLASS_RESERVED (\(String(format: "0x%02x", rawValue)))"
    }
  }
}

extension QueryDirectory.Flags: CustomDebugStringConvertible {
  public var debugDescription: String {
    var values = [String]()
    if contains(.restartScans) {
      values.append("Restart Scans")
    }
    if contains(.returnSingleEntry) {
      values.append("Single Entry")
    }
    if contains(.indexSpecified) {
      values.append("Index Specified")
    }
    if contains(.reopen) {
      values.append("Reopen")
    }

    if values.isEmpty {
      return "\(String(format: "0x%02x", rawValue))"
    } else {
      return "\(String(format: "0x%02x", rawValue)) (\(values.joined(separator: ", ")))"
    }
  }
}

extension QueryDirectory.FileIdBothDirectoryInformation: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    FileIdBothDirectoryInfo:
      Next Offset: \(nextEntryOffset)
      File Index: \(fileIndex)
      Create: \(FileTime(creationTime))
      Last Access: \(FileTime(lastAccessTime))
      Last Write: \(FileTime(lastWriteTime))
      Last Change: \(FileTime(changeTime))
      End Of File: \(endOfFile)
      Allocation Size: \(allocationSize)
      File Attributes: \(fileAttributes)
      File Name: \(fileName)
    """
  }
}
