import Foundation

public struct Header {
  public let protocolId: UInt32
  public let structureSize: UInt16
  public internal(set) var creditCharge: UInt16
  public let status: UInt32
  public let command: UInt16
  public let creditRequestResponse: UInt16
  public internal(set) var flags: Flags
  public internal(set) var nextCommand: UInt32
  public let messageId: UInt64
  public let reserved: UInt32
  public let treeId: UInt32
  public let sessionId: UInt64
  public internal(set) var signature: Data

  public init(
    creditCharge: UInt16 = 1,
    command: Command,
    creditRequest: UInt16 = 0,
    flags: Flags = [],
    nextCommand: UInt32 = 0,
    messageId: UInt64,
    treeId: UInt32 = 0,
    sessionId: UInt64
  ) {
    self.protocolId = 0x424D53FE
    self.structureSize = 64
    self.creditCharge = creditCharge
    self.status = 0
    self.command = command.rawValue
    self.creditRequestResponse = creditRequest
    self.flags = flags
    self.nextCommand = nextCommand
    self.messageId = messageId
    self.reserved = 0
    self.treeId = treeId
    self.sessionId = sessionId
    self.signature = Data(count: 16)
  }

  init(data: Data) {
    let reader = ByteReader(data)

    protocolId = reader.read()
    structureSize = reader.read()
    creditCharge = reader.read()
    status = reader.read()
    command = reader.read()
    creditRequestResponse = reader.read()
    flags = Flags(rawValue: reader.read())
    nextCommand = reader.read()
    messageId = reader.read()
    reserved = reader.read()
    treeId = reader.read()
    sessionId = reader.read()
    signature = reader.read(count: 16)
  }

  public func encoded() -> Data {
    var data = Data()

    data += protocolId
    data += structureSize
    data += creditCharge
    data += status
    data += command
    data += creditRequestResponse
    data += flags.rawValue
    data += nextCommand
    data += messageId
    data += reserved
    data += treeId
    data += sessionId
    data += signature

    return data
  }

  public enum Command: UInt16 {
    case negotiate = 0x0000
    case sessionSetup = 0x0001
    case logoff = 0x0002
    case treeConnect = 0x0003
    case treeDisconnect = 0x0004
    case create = 0x0005
    case close = 0x0006
    case flush = 0x0007
    case read = 0x0008
    case write = 0x0009
    case lock = 0x000A
    case ioctl = 0x000B
    case cancel = 0x000C
    case echo = 0x000D
    case queryDirectory = 0x000E
    case changeNotify = 0x000F
    case queryInfo = 0x0010
    case setInfo = 0x0011
    case oplockBreak = 0x0012
    case serverToClientNotification = 0x0013
  }

  public struct Flags: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    public static let serverToRedir = Flags(rawValue: 0x00000001)
    public static let asyncCommand = Flags(rawValue: 0x00000002)
    public static let relatedOperations = Flags(rawValue: 0x00000004)
    public static let signed = Flags(rawValue: 0x00000008)
    public static let priorityMask = Flags(rawValue: 0x00000070)
    public static let dfsOperation = Flags(rawValue: 0x10000000)
    public static let replayOperation = Flags(rawValue: 0x20000000)
  }
}

extension ByteReader {
  func read() -> Header {
    Header(data: read(count: 64))
  }
}

extension Header: CustomDebugStringConvertible {
  public var debugDescription: String {
    if flags.contains(.serverToRedir) {
      return
        """
        SMB2 Header
          ProtocolId: 0x\(String(format: "%08x", protocolId.bigEndian))
          Credit Charge: \(creditCharge)
          NT Status: 0x\(String(format: "%08x", status))
          Command: \(Command.debugDescription(command)) (\(command))
          Credits granted: \(creditRequestResponse)
          Flags: 0x\(String(format: "%08x", flags.rawValue)) (\(flags))
          Chain Offset: \(nextCommand)
          Message ID: \(String(messageId, radix: 16))
          Process Id: 0x\(String(format: "%08x", reserved))
          Tree Id: 0x\(String(format: "%08x", treeId))
          Session Id: 0x\(String(format: "%016llx", sessionId))
          Signature: \(signature.hex)
        """
    } else {
      return
        """
        SMB2 Header
          ProtocolId: 0x\(String(format: "%08x", protocolId.bigEndian))
          Credit Charge: \(creditCharge)
          Channel Sequence: \(String((status & 0xFFFF0000) >> 16, radix: 16))
          Reserved: \(String(format: "%04x", status & 0x0000FFFF))
          Command: \(Command.debugDescription(command)) (\(command))
          Credits requested: \(creditRequestResponse)
          Flags: 0x\(String(format: "%08x", flags.rawValue)) (\(flags))
          Chain Offset: \(nextCommand)
          Message ID: \(String(messageId, radix: 16))
          Process Id: 0x\(String(format: "%08x", reserved))
          Tree Id: 0x\(String(format: "%08x", treeId))
          Session Id: 0x\(String(format: "%016llx", sessionId))
          Signature: \(signature.hex)
        """
    }
  }
}

extension Header.Command {
  static func debugDescription(_ rawValue: UInt16) -> String {
    switch rawValue {
    case Self.negotiate.rawValue: return "NEGOTIATE"
    case Self.sessionSetup.rawValue: return "SESSION_SETUP"
    case Self.logoff.rawValue: return "LOGOFF"
    case Self.treeConnect.rawValue: return "TREE_CONNECT"
    case Self.treeDisconnect.rawValue: return "TREE_DISCONNECT"
    case Self.create.rawValue: return "CREATE"
    case Self.close.rawValue: return "CLOSE"
    case Self.flush.rawValue: return "FLUSH"
    case Self.read.rawValue: return "READ"
    case Self.write.rawValue: return "WRITE"
    case Self.lock.rawValue: return "LOCK"
    case Self.ioctl.rawValue: return "IOCTL"
    case Self.cancel.rawValue: return "CANCEL"
    case Self.echo.rawValue: return "ECHO"
    case Self.queryDirectory.rawValue: return "QUERY_DIRECTORY"
    case Self.changeNotify.rawValue: return "CHANGE_NOTIFY"
    case Self.queryInfo.rawValue: return "QUERY_INFO"
    case Self.setInfo.rawValue: return "SET_INFO"
    case Self.oplockBreak.rawValue: return "OPLOCK_BREAK"
    case Self.serverToClientNotification.rawValue: return "SERVER_TO_CLIENT_NOTIFICATION"
    default: return "UNKNOWN"
    }
  }
}

extension Header.Flags: CustomDebugStringConvertible {
  public var debugDescription: String {
    var flags: [String] = []
    if contains(.serverToRedir) {
      flags.append("SERVER_TO_REDIR")
    }
    if contains(.asyncCommand) {
      flags.append("ASYNC_COMMAND")
    }
    if contains(.relatedOperations) {
      flags.append("RELATED_OPERATIONS")
    }
    if contains(.signed) {
      flags.append("SIGNED")
    }
    if contains(.priorityMask) {
      flags.append("PRIORITY_MASK")
    }
    if contains(.dfsOperation) {
      flags.append("DFS_OPERATION")
    }
    if contains(.replayOperation) {
      flags.append("REPLAY_OPERATION")
    }
    return flags.joined(separator: "|")
  }
}
