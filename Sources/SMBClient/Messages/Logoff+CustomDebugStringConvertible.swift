import Foundation

extension Logoff.Request: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Session Logoff Request (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Reserved: \(String(format: "%04x", reserved))
    """
  }
}

extension Logoff.Response: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Session Logoff Response (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Reserved: \(String(format: "%04x", reserved))
    """
  }
}
