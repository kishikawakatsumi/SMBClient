import Foundation

extension QueryInfo.Request: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    GetInfo Request (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Class: \(infoType)
      InfoLevel: \(fileInfoClass)
      Max Response Size: \(outputBufferLength)
      Getinfo Input Offset: \(inputBufferOffset)
      Reserved: \(String(format: "%04x", reserved))
      Getinfo Input Size: \(inputBufferLength)
      Additional Info: \(String(format: "0x%08x", additionalInformation))
      Flags: \(flags)
      GUID handle: \(UUID(data: fileId))
    """
  }
}

extension QueryInfo.Response: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    GetInfo Response (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Blob Offset: \(outputBufferOffset)
      Blob Length: \(outputBufferLength)
      Data: \(buffer.hex)
    """
  }
}

extension QueryInfo.Flags: CustomDebugStringConvertible {
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

    if values.isEmpty {
      return "\(String(format: "0x%02x", rawValue))"
    } else {
      return "\(String(format: "0x%02x", rawValue)) (\(values.joined(separator: ", ")))"
    }
  }
}
