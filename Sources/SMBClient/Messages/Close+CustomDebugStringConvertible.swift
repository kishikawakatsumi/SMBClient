import Foundation

extension Close.Request: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Close Request (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Close Flags: \(flags)
      Reserved: \(String(format: "%04x", reserved))
      GUID handle File: \(UUID(data: fileId))
    """
  }
}

extension Close.Response: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Close Response (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Flags: \(flags)
      Reserved: \(String(format: "%04x", reserved))
      Create: \(FileTime(creationTime))
      Last Access: \(FileTime(lastAccessTime))
      Last Write: \(FileTime(lastWriteTime))
      Last Change: \(FileTime(changeTime))
      Allocation Size: \(allocationSize)
      End Of File: \(endOfFile)
      File Attributes: \(FileAttributes(rawValue: fileAttributes))
    """
  }
}

extension Close.Flags: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .postQueryAttrib:
      return "\(String(format: "0x%04x", rawValue)) (PostQuery Attrib: True)"
    }
  }
}
