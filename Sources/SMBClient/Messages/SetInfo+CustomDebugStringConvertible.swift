import Foundation

extension SetInfo.Request: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    SetInfo Request (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Class: \(infoType)
      InfoLevel: \(fileInfoClass)
      Setinfo Size: \(bufferLength)
      Setinfo Offset: \(bufferOffset)
      Reserved: \(String(format: "%04x", reserved))
      Additional Info: \(String(format: "0x%08x", additionalInformation))
      GUID handle: \(fileId.to(type: UUID.self))
      Data: \(buffer.hex)
    """
  }
}

extension SetInfo.Response: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    SetInfo Response (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
    """
  }
}
