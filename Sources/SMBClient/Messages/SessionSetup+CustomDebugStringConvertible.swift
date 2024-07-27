import Foundation

extension SessionSetup.Request: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Session Setup Request (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Flags: \(flags.rawValue)
      Security mode: 0x\(String(format: "%04x", securityMode.rawValue)) (\(securityMode))
      Capabilities: \(capabilities)
      Channel: \(String(format: "0x%08x", channel))
      Blob Offset: \(securityBufferOffset)
      Blob Length: \(securityBufferLength)
      Previous Session Id: \(String(format: "0x%016llx", previousSessionId))
      Security Blob: \(securityBuffer.hex)
    """
  }
}

extension SessionSetup.Response: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Session Setup Response (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Session Flags: \(sessionFlags)
      Blob Offset: \(securityBufferOffset)
      Blob Length: \(securityBufferLength)
      Security Blob: \(buffer.hex)
    """
  }
}

extension SessionSetup.Flags: CustomDebugStringConvertible {
  public var debugDescription: String {
    var values = [String]()
    if contains(.binding) {
      values.append("Session Binding Request")
    }

    if values.isEmpty {
      return "0x\(String(format: "%02x", rawValue))"
    } else {
      return "0x\(String(format: "%02x", rawValue)) (\(values.joined(separator: ", ")))"
    }
  }
}

extension SessionSetup.SecurityMode: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .signingEnabled:
      return "Signing enabled"
    case .signingRequired:
      return "Signing required"
    default:
      return "0x\(String(format: "%02x", rawValue))"
    }
  }
}

extension SessionSetup.Capabilities: CustomDebugStringConvertible {
  public var debugDescription: String {
    var values = [String]()

    if contains(.dfs) {
      values.append("DFS")
    }
    if contains(.unused1) {
      values.append("Unused1")
    }
    if contains(.unused2) {
      values.append("Unused2")
    }
    if contains(.unused3) {
      values.append("Unused3")
    }

    if values.isEmpty {
      return "0x\(String(format: "%08x", rawValue))"
    } else {
      return "0x\(String(format: "%08x", rawValue)) (\(values.joined(separator: ", ")))"
    }
  }
}

extension SessionSetup.SessionFlags: CustomDebugStringConvertible {
  public var debugDescription: String {
    var values = [String]()

    if contains(.guest) {
      values.append("Guest")
    }
    if contains(.nullSession) {
      values.append("Null")
    }
    if contains(.encryptData) {
      values.append("Encrypt")
    }

    if values.isEmpty {
      return "0x\(String(format: "%04x", rawValue))"
    } else {
      return "0x\(String(format: "%04x", rawValue)) (\(values.joined(separator: ", ")))"
    }
  }
}
