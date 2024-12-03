import Foundation

extension Write.Request: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Write Request (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Data Offset: \(dataOffset)
      Write Length: \(length)
      File Offset: \(offset)
      GUID handle: \(fileId.to(type: UUID.self))
      Channel: 0x\(String(format: "%08x", channel))
      Remaining Bytes: \(remainingBytes)
      Write Flags: \(flags)
      Blob Offset: \(writeChannelInfoOffset)
      Blob Length: \(writeChannelInfoLength)
      Channel Info Blob: \(buffer.hex)
    """
  }
}

extension Write.Response: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Read Response (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Reserved: \(String(format: "%04x", reserved))
      Write Count: \(count)
      Write Remaining: \(remaining)
      Channel Info Offset: \(writeChannelInfoOffset)
      Channel Info Length: \(writeChannelInfoLength)
    """
  }
}

extension Write.Flags: CustomDebugStringConvertible {
  public var debugDescription: String {
    var values = [String]()

    if contains(.writeThrough) {
      values.append("Write Through")
    }
    if contains(.writeUnbuffered) {
      values.append("Unbuffered")
    }

    if values.isEmpty {
      return "0x\(String(format: "%08x", rawValue))"
    } else {
      return "0x\(String(format: "%08x", rawValue)) (\(values.joined(separator: ", ")))"
    }
  }
}
