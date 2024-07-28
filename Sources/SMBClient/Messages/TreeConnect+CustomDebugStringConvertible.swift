import Foundation

extension TreeConnect.Request: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Tree Connect Request (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Reserved: \(String(format: "%04x", reserved))
      Blob Offset: \(pathOffset)
      Blob Length: \(pathLength)
      Tree: \(String(data: buffer, encoding: .utf16LittleEndian) ?? buffer.hex)
    """
  }
}

extension TreeConnect.Response: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Tree Connect Response (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Share Type: \(shareType)
      Reserved: \(String(format: "%02x", reserved))
      Share flags: \(shareFlags)
      Share capabilities: \(capabilities)
      Access Mask: \(FilePipePrinterAccessMask(rawValue: maximalAccess))
    """
  }
}

extension TreeConnect.ShareType: CustomDebugStringConvertible {
  public var debugDescription: String {
    let value: String

    switch self {
    case .disk:
      value = "Physical Disk"
    case .pipe:
      value = "Named pipe"
    case .print:
      value = "Printer"
    }

    return "\(value) (\(String(format: "0x%02x", rawValue)))"
  }
}

extension TreeConnect.ShareFlags: CustomDebugStringConvertible {
  public var debugDescription: String {
    var values = [String]()
    if contains(.manualCaching) {
      values.append("Manual caching")
    }
    if contains(.autoCaching) {
      values.append("Auto caching")
    }
    if contains(.vdoCaching) {
      values.append("VDO caching")
    }
    if contains(.noCaching) {
      values.append("No caching")
    }
    if contains(.dfs) {
      values.append("DFS")
    }
    if contains(.dfsRoot) {
      values.append("DFS root")
    }
    if contains(.restrectExclusiveOpens) {
      values.append("Restrict exclusive opens")
    }
    if contains(.forceSharedDelete) {
      values.append("Force shared delete")
    }
    if contains(.allowNamespaceCaching) {
      values.append("Allow namespace caching")
    }
    if contains(.accessBasedDirectoryEnum) {
      values.append("Access based directory enum")
    }
    if contains(.forceLevelIIOplock) {
      values.append("Force level II oplock")
    }
    if contains(.enableHashV1) {
      values.append("Enable hash V1")
    }
    if contains(.enableHashV2) {
      values.append("Enable hash V2")
    }
    if contains(.encryptData) {
      values.append("Encrypted data required")
    }
    if contains(.identityRemoting) {
      values.append("Identity Remoting")
    }
    if contains(.compressData) {
      values.append("Compressed IO")
    }
    if contains(.isolatedTransport) {
      values.append("Isolated Transport")
    }

    if values.isEmpty {
      return "\(String(format: "0x%02x", rawValue))"
    } else {
      return "\(String(format: "0x%02x", rawValue)) (\(values.joined(separator: ", ")))"
    }
  }
}

extension TreeConnect.Capabilities: CustomDebugStringConvertible {
  public var debugDescription: String {
    var values = [String]()

    if contains(.dfs) {
      values.append("DFS")
    }
    if contains(.continuousAvailability) {
      values.append("CONTINUOUS AVAILABILITY")
    }
    if contains(.scaleout) {
      values.append("SCALEOUT")
    }
    if contains(.cluster) {
      values.append("CLUSTER")
    }
    if contains(.asymmetric) {
      values.append("ASYMMETRIC")
    }
    if contains(.redirectToOwner) {
      values.append("REDIRECT_TO_OWNER")
    }

    if values.isEmpty {
      return "\(String(format: "0x%08x", rawValue))"
    } else {
      return "\(String(format: "0x%08x", rawValue)) (\(values.joined(separator: ", ")))"
    }
  }
}
