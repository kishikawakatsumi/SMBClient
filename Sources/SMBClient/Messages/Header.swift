import Foundation

public struct Header {
  public let protocolId: UInt32
  public let structureSize: UInt16
  public internal(set) var creditCharge: UInt16
  public let status: UInt32
  public let command: UInt16
  public let creditRequestResponse: UInt16
  public let flags: Flags
  public internal(set) var nextCommand: UInt32
  public let messageId: UInt64
  public let reserved: UInt32
  public let treeId: UInt32
  public let sessionId: UInt64
  public let signature: Data

  public init(
    creditCharge: UInt16 = 0,
    command: Command,
    creditRequest: UInt16 = 0,
    flags: Flags,
    nextCommand: UInt32,
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

  public init(
    creditCharge: UInt16,
    command: UInt16,
    creditRequest: UInt16,
    flags: Flags,
    nextCommand: UInt32,
    messageId: UInt64,
    treeId: UInt32,
    sessionId: UInt64
  ) {
    self.protocolId = 0x424D53FE
    self.structureSize = 64
    self.creditCharge = creditCharge
    self.status = 0
    self.command = command
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
    let data = read(count: 64)
    return Header(data: Data(data))
  }
}
