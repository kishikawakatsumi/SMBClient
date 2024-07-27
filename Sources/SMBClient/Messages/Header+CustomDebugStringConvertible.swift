import Foundation

extension Header: CustomDebugStringConvertible {
  public var debugDescription: String {
    if flags.contains(.serverToRedir) {
      return
        """
        SMB2 Header
          ProtocolId: \(String(format: "0x%08x", protocolId.bigEndian))
          Header Length: \(structureSize)
          Credit Charge: \(creditCharge)
          NT Status: \(NTStatus(status).debugDescription) (\(String(format: "0x%08x", status)))
          Command: \(Command.debugDescription(rawValue: command)) (\(command))
          Credits granted: \(creditRequestResponse)
          Flags: \(flags)
          Chain Offset: \(nextCommand)
          Message ID: \(String(messageId, radix: 16))
          Process Id: \(String(format: "0x%08x", reserved))
          Tree Id: \(String(format: "0x%08x", treeId))
          Session Id: \(String(format: "0x%016llx", sessionId))
          Signature: \(signature.hex)
        """
    } else {
      return
        """
        SMB2 Header
          ProtocolId: \(String(format: "0x%08x", protocolId.bigEndian))
          Header Length: \(structureSize)
          Credit Charge: \(creditCharge)
          Channel Sequence: \(String((status & 0xFFFF0000) >> 16, radix: 16))
          Reserved: \(String(format: "%04x", status & 0x0000FFFF))
          Command: \(Command.debugDescription(rawValue: command)) (\(command))
          Credits requested: \(creditRequestResponse)
          Flags: \(flags)
          Chain Offset: \(nextCommand)
          Message ID: \(String(messageId, radix: 16))
          Process Id: \(String(format: "0x%08x", reserved))
          Tree Id: \(String(format: "0x%08x", treeId))
          Session Id: \(String(format: "0x%016llx", sessionId))
          Signature: \(signature.hex)
        """
    }
  }
}

extension Header.Command: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .negotiate: return "Negotiate Protocol"
    case .sessionSetup: return "SESSION_SETUP"
    case .logoff: return "LOGOFF"
    case .treeConnect: return "TREE_CONNECT"
    case .treeDisconnect: return "TREE_DISCONNECT"
    case .create: return "CREATE"
    case .close: return "CLOSE"
    case .flush: return "FLUSH"
    case .read: return "READ"
    case .write: return "WRITE"
    case .lock: return "LOCK"
    case .ioctl: return "IOCTL"
    case .cancel: return "CANCEL"
    case .echo: return "ECHO"
    case .queryDirectory: return "QUERY_DIRECTORY"
    case .changeNotify: return "CHANGE_NOTIFY"
    case .queryInfo: return "QUERY_INFO"
    case .setInfo: return "SET_INFO"
    case .oplockBreak: return "OPLOCK_BREAK"
    case .serverToClientNotification: return "SERVER_TO_CLIENT_NOTIFICATION"
    }
  }

  static public func debugDescription(rawValue: UInt16) -> String {
    if let command = Header.Command(rawValue: rawValue) {
      return command.debugDescription
    } else {
      return String(format: "0x%04x", rawValue)
    }
  }
}

extension Header.Flags: CustomDebugStringConvertible {
  public var debugDescription: String {
    var values: [String] = []
    
    if contains(.serverToRedir) {
      values.append("Response")
    }
    if contains(.asyncCommand) {
      values.append("Async command")
    }
    if contains(.relatedOperations) {
      values.append("Chained")
    }
    if contains(.signed) {
      values.append("Signing")
    }
    if contains(.priorityMask) {
      values.append("Priority")
    }
    if contains(.dfsOperation) {
      values.append("DFS operation")
    }
    if contains(.replayOperation) {
      values.append("Replay operation")
    }

    if values.isEmpty {
      return String(format: "0x%08x", rawValue)
    } else {
      return "\(String(format: "0x%08x", rawValue)) (\(values.joined(separator: ", ")))"
    }
  }
}
