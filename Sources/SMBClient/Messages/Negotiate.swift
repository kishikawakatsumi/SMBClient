import Foundation

public enum Negotiate {
  public struct Request {
    public let header: Header
    public let structureSize: UInt16
    public let dialectCount: UInt16
    public let securityMode: SecurityMode
    public let reserved: UInt16
    public let capabilities: Capabilities
    public let clientGuid: UUID
    public let clientStartTime: UInt64
    public let dialects: [Dialects]
    public let padding: Data
    public let negotiateContextList: Data

    public init(
      headerFlags: Header.Flags = [],
      messageId: UInt64,
      securityMode: SecurityMode,
      dialects: [Dialects]
    ) {
      header = Header(
        creditCharge: 1,
        command: .negotiate,
        creditRequest: 0,
        flags: headerFlags,
        messageId: messageId,
        treeId: 0,
        sessionId: 0
      )

      structureSize  = 36
      dialectCount = UInt16(dialects.count)
      self.securityMode = securityMode
      reserved = 0
      capabilities = []
      clientGuid = UUID()
      clientStartTime = 0
      self.dialects = dialects
      padding = Data(count: (dialects.count * 2) % 8)
      negotiateContextList = Data()
    }

    public func encoded() -> Data {
      var data = Data()

      data += header.encoded()

      data += structureSize
      data += dialectCount
      data += securityMode.rawValue
      data += reserved
      data += capabilities.rawValue
      data += clientGuid.data
      data += clientStartTime

      for dialect in dialects {
        data += dialect.rawValue
      }
      data += padding
      data += negotiateContextList

      return data
    }
  }

  public struct Response {
    public let header: Header
    public let structureSize: UInt16
    public let securityMode: SecurityMode
    public let dialectRevision: UInt16
    public let negotiateContextCount: UInt16
    public let serverGuid: UUID
    public let capabilities: Capabilities
    public let maxTransactSize: UInt32
    public let maxReadSize: UInt32
    public let maxWriteSize: UInt32
    public let systemTime: UInt64
    public let serverStartTime: UInt64
    public let securityBufferOffset: UInt16
    public let securityBufferLength: UInt16
    public let negotiateContextOffset: UInt32
    public let securityBuffer: Data

    public init(data: Data) {
      let reader = ByteReader(data)

      header = reader.read()

      structureSize = reader.read()
      securityMode = SecurityMode(rawValue: reader.read())
      dialectRevision = reader.read()
      negotiateContextCount = reader.read()
      serverGuid = reader.read()
      capabilities = Capabilities(rawValue: reader.read())
      maxTransactSize = reader.read()
      maxReadSize = reader.read()
      maxWriteSize = reader.read()
      systemTime = reader.read()
      serverStartTime = reader.read()
      securityBufferOffset = reader.read()
      securityBufferLength = reader.read()
      negotiateContextOffset = reader.read()
      securityBuffer = reader.read(from: Int(securityBufferOffset), count: Int(securityBufferLength))
    }
  }

  public struct SecurityMode: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
      self.rawValue = rawValue
    }

    public static let signingEnabled = SecurityMode(rawValue: 0x0001)
    public static let signingRequired = SecurityMode(rawValue: 0x0002)
  }

  public struct Capabilities: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    public static let dfs = Capabilities(rawValue: 0x00000001)
    public static let leasing = Capabilities(rawValue: 0x00000002)
    public static let largeMtu = Capabilities(rawValue: 0x00000004)
    public static let multiChannel = Capabilities(rawValue: 0x00000008)
    public static let persistentHandles = Capabilities(rawValue: 0x00000010)
    public static let directoryLeasing = Capabilities(rawValue: 0x00000020)
    public static let encryption = Capabilities(rawValue: 0x00000040)
    public static let notifications = Capabilities(rawValue: 0x00000080)
  }

  public enum Dialects: UInt16 {
    case smb202 = 0x0202
    case smb210 = 0x0210
    case smb300 = 0x0300
    case smb302 = 0x0302
    case smb311 = 0x0311
  }
}

extension Negotiate.Response: CustomDebugStringConvertible {
  public var debugDescription: String {
    "{header: \(header), " +
    "structureSize: \(structureSize), " +
    "securityMode: \(securityMode), " +
    "dialectRevision: \(String(format: "0x%04X", dialectRevision)), " +
    "negotiateContextCount: \(negotiateContextCount), " +
    "serverGuid: \(serverGuid), " +
    "capabilities: \(capabilities), " +
    "maxTransactSize: \(maxTransactSize), " +
    "maxReadSize: \(maxReadSize), " +
    "maxWriteSize: \(maxWriteSize), " +
    "systemTime: \(FileTime(systemTime).date), " +
    "serverStartTime: \(FileTime(serverStartTime).date), " +
    "securityBufferOffset: \(securityBufferOffset), " +
    "securityBufferLength: \(securityBufferLength), " +
    "negotiateContextOffset: \(negotiateContextOffset), " +
    "securityBuffer: \(securityBuffer.hex)}"
  }
}

extension Negotiate.SecurityMode: CustomDebugStringConvertible {
  public var debugDescription: String {
    var values = [String]()
    if contains(.signingEnabled) {
      values.append("signingEnabled")
    }
    if contains(.signingRequired) {
      values.append("signingRequired")
    }
    return values.joined(separator: "|")
  }
}

extension Negotiate.Capabilities: CustomDebugStringConvertible {
  public var debugDescription: String {
    var values = [String]()
    if contains(.dfs) {
      values.append("dfs")
    }
    if contains(.leasing) {
      values.append("leasing")
    }
    if contains(.largeMtu) {
      values.append("largeMtu")
    }
    if contains(.multiChannel) {
      values.append("multiChannel")
    }
    if contains(.persistentHandles) {
      values.append("persistentHandles")
    }
    if contains(.directoryLeasing) {
      values.append("directoryLeasing")
    }
    if contains(.encryption) {
      values.append("encryption")
    }
    if contains(.notifications) {
      values.append("notifications")
    }
    return values.joined(separator: "|")
  }
}
