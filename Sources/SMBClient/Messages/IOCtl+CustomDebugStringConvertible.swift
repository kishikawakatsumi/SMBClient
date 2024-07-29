import Foundation

extension IOCtl.Request: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Ioctl Request (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Reserved: \(String(format: "%04x", reserved))
      Function: \(IOCtl.CtlCode.debugDescription(rawValue: ctlCode)) (\(String(format: "0x%08x", ctlCode)))
      GUID handle File: \(UUID(data: fileId))
      Blob Offset: \(inputOffset)
      Blob Length: \(inputCount)
      Max Ioctl In Size: \(maxInputResponse)
      Blob Offset: \(outputOffset)
      Blob Length: \(outputCount)
      Max Ioctl Out Size: \(maxOutputResponse)
      Flags: \(flags)
      Reserved: \(String(format: "%08x", reserved))
      Buffer: \(buffer.hex)
    """
  }
}

extension IOCtl.Response: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Ioctl Response (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Reserved: \(String(format: "%04x", reserved))
      Function: \(IOCtl.CtlCode.debugDescription(rawValue: ctlCode)) (\(String(format: "0x%08x", ctlCode)))
      GUID handle File: \(UUID(data: fileId))
      Blob Offset: \(inputOffset)
      Blob Length: \(inputCount)
      Blob Offset: \(outputOffset)
      Blob Length: \(outputCount)
      Flags: \(flags)
      Reserved: \(String(format: "%08x", reserved))
      Buffer: \(buffer.hex)
    """
  }
}

extension IOCtl.CtlCode: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .dfsGetReferrals:
      return "FSCTL_DFS_GET_REFERRALS"
    case .pipePeek:
      return "FSCTL_PIPE_PEEK"
    case .pipeWait:
      return "FSCTL_PIPE_WAIT"
    case .pipeTransceive:
      return "FSCTL_PIPE_TRANSCEIVE"
    case .srvCopyChunk:
      return "FSCTL_SRV_COPYCHUNK"
    case .srvEnumerateSnapshots:
      return "FSCTL_SRV_ENUMERATE_SNAPSHOTS"
    case .srvRequestResumeKey:
      return "FSCTL_SRV_REQUEST_RESUME_KEY"
    case .srvReadHash:
      return "FSCTL_SRV_READ_HASH"
    case .srvCopyChunkWrite:
      return "FSCTL_SRV_COPYCHUNK_WRITE"
    case .lmrRequestResiliency:
      return "FSCTL_LMR_REQUEST_RESILIENCY"
    case .queryNetworkInterfaceInfo:
      return "FSCTL_QUERY_NETWORK_INTERFACE_INFO"
    case .setReleasePoint:
      return "FSCTL_SET_REPARSE_POINT"
    case .dfsGetReferralsEx:
      return "FSCTL_DFS_GET_REFERRALS_EX"
    case .fileLevelTrim:
      return "FSCTL_FILE_LEVEL_TRIM"
    case .validateNegotiateInfo:
      return "FSCTL_VALIDATE_NEGOTIATE_INFO"
    }
  }

  static public func debugDescription(rawValue: UInt32) -> String {
    if let ctlCode = IOCtl.CtlCode(rawValue: rawValue) {
      return ctlCode.debugDescription
    } else {
      return String(format: "0x%08x", rawValue)
    }
  }
}

extension IOCtl.Flags: CustomDebugStringConvertible {
  public var debugDescription: String {
    var values = [String]()

    if contains(.isFsctl) {
      values.append("Is FSCTL: True")
    }

    if values.isEmpty {
      return "0x\(String(format: "%08x", rawValue))"
    } else {
      return "0x\(String(format: "%08x", rawValue)) (\(values.joined(separator: ", ")))"
    }
  }
}
