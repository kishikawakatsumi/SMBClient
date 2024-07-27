import Foundation

extension Echo.Request: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    KeepAlive Request (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Reserved: \(String(format: "%04x", reserved))
    """
  }
}

extension Echo.Response: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    KeepAlive Response (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Reserved: \(String(format: "%04x", reserved))
    """
  }
}
