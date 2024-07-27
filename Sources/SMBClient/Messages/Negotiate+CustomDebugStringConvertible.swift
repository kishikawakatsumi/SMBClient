import Foundation

extension Negotiate.Request: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Negotiate Protocol Request (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      DialectCount: \(dialectCount)
      Security mode: \(securityMode)
      Reserved: \(String(format: "%04x", reserved))
      Capabilities: \(capabilities)
      Client Guid: \(clientGuid)
      Client Start Time: \(clientStartTime)
    \(dialects.map { "  Dialect: \($0)" }.joined(separator: "\n"))
      Padding: \(padding.hex)
      NegotiateContextList: \(negotiateContextList.hex)
    """
  }
}

extension Negotiate.Response: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Negotiate Protocol Response (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Security mode: \(securityMode)
      Dialect: \(String(format: "0x%04x", dialectRevision))
      NegotiateContextCount: \(negotiateContextCount)
      Server Guid: \(serverGuid)
      Capabilities: \(capabilities)
      Max Transaction Size: \(maxTransactSize)
      Max Read Size: \(maxReadSize)
      Max Write Size: \(maxWriteSize)
      Current Time: \(FileTime(systemTime))
      Boot Time: \(FileTime(serverStartTime))
      Blob Offset: \(securityBufferOffset)
      Blob Length: \(securityBufferLength)
      Security Blob: \(securityBuffer.hex)
      NegotiateContextOffset: \(String(format: "0x%08x", negotiateContextOffset))
    """
  }
}

extension Negotiate.SecurityMode: CustomDebugStringConvertible {
  public var debugDescription: String {
    var values = [String]()
    if contains(.signingEnabled) {
      values.append("Signing enabled")
    }
    if contains(.signingRequired) {
      values.append("Signing required")
    }

    if values.isEmpty {
      return "\(String(format: "0x%04x", rawValue))"
    } else {
      return "\(String(format: "0x%04x", rawValue)) (\(values.joined(separator: ", ")))"
    }
  }
}

extension Negotiate.Capabilities: CustomDebugStringConvertible {
  public var debugDescription: String {
    var values = [String]()

    if contains(.dfs) {
      values.append("DFS")
    }
    if contains(.leasing) {
      values.append("LEASING")
    }
    if contains(.largeMtu) {
      values.append("LARGE MTU")
    }
    if contains(.multiChannel) {
      values.append("MULTI CHANNEL")
    }
    if contains(.persistentHandles) {
      values.append("PERSISTENT HANDLES")
    }
    if contains(.directoryLeasing) {
      values.append("DIRECTORY LEASING")
    }
    if contains(.encryption) {
      values.append("ENCRYPTION")
    }
    if contains(.notifications) {
      values.append("NOTIFICATIONS")
    }

    if values.isEmpty {
      return "\(String(format: "0x%08x", rawValue))"
    } else {
      return "\(String(format: "0x%08x", rawValue)) (\(values.joined(separator: ", ")))"
    }
  }
}

extension Negotiate.Dialects: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .smb202:
      return "SMB 2.0.2 (\(String(format: "0x%04x", rawValue)))"
    case .smb210:
      return "SMB 2.1.0 (\(String(format: "0x%04x", rawValue)))"
    case .smb300:
      return "SMB 3.0.0 (\(String(format: "0x%04x", rawValue)))"
    case .smb302:
      return "SMB 3.0.2 (\(String(format: "0x%04x", rawValue)))"
    case .smb311:
      return "SMB 3.1.1 (\(String(format: "0x%04x", rawValue)))"
    }
  }
}
