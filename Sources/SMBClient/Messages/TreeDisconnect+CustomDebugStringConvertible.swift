import Foundation

extension TreeDisconnect.Request: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    TreeDisconnect Request (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Reserved: \(String(format: "%04x", reserved))
    """
  }
}

extension TreeDisconnect.Response: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    TreeDisconnect Response (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Reserved: \(String(format: "%04x", reserved))
    """
  }
}
