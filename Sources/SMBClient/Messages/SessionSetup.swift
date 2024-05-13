import Foundation

public enum SessionSetup {
  public struct Request {
    public let header: Header
    public let structureSize: UInt16
    public let flags: Flags
    public let securityMode: SecurityMode
    public let capabilities: Capabilities
    public let channel: UInt32
    public let securityBufferOffset: UInt16
    public let securityBufferLength: UInt16
    public let previousSessionId: UInt64
    public let securityBuffer: Data

    public struct Flags: OptionSet {
      public let rawValue: UInt8

      public init(rawValue: UInt8) {
        self.rawValue = rawValue
      }

      public static let binding = Flags(rawValue: 0x0001)
    }

    public struct SecurityMode: OptionSet {
      public let rawValue: UInt8

      public init(rawValue: UInt8) {
        self.rawValue = rawValue
      }

      public static let signingEnabled = SecurityMode(rawValue: 0x0001)
      public static let signingRequired = SecurityMode(rawValue: 0x0002)
    }

    public struct Capabilities: OptionSet {
      public let rawValue: UInt32

      public init(rawValue: UInt32) {
        self.rawValue = rawValue
      }

      public static let dfs = Capabilities(rawValue: 0x00000001)
      public static let unused1 = Capabilities(rawValue: 0x00000002)
      public static let unused2 = Capabilities(rawValue: 0x00000004)
      public static let unused3 = Capabilities(rawValue: 0x00000008)
    }

    public init(
      messageId: UInt64,
      sessionId: UInt64 = 0,
      securityMode: SecurityMode,
      capabilities: Capabilities,
      previousSessionId: UInt64,
      securityBuffer: Data
    ) {
      header = Header(
        creditCharge: 1,
        command: .sessionSetup,
        creditRequest: 64,
        flags: [],
        nextCommand: 0,
        messageId: messageId,
        sessionId: sessionId
      )

      self.structureSize = 25
      self.flags = []
      self.securityMode = securityMode
      self.capabilities = capabilities
      self.channel = 0
      self.securityBufferOffset = 88
      self.securityBufferLength = UInt16(truncatingIfNeeded: securityBuffer.count)
      self.previousSessionId = previousSessionId
      self.securityBuffer = securityBuffer
    }

    public func encoded() -> Data {
      var data = Data()
      data += header.encoded()
      data += structureSize
      data += flags.rawValue
      data += securityMode.rawValue
      data += capabilities.rawValue
      data += channel
      data += securityBufferOffset
      data += securityBufferLength
      data += previousSessionId
      data += securityBuffer
      return data
    }
  }

  public struct Response {
    public let header: Header

    public let structureSize: UInt16
    public let sessionFlags: SessionFlags
    public let securityBufferOffset: UInt16
    public let securityBufferLength: UInt16
    public let buffer: Data

    public struct SessionFlags: OptionSet {
      public let rawValue: UInt16

      public init(rawValue: UInt16) {
        self.rawValue = rawValue
      }

      public static let guest = SessionFlags(rawValue: 0x0001)
      public static let nullSession = SessionFlags(rawValue: 0x0002)
      public static let encryptData = SessionFlags(rawValue: 0x0004)
    }

    public init(data: Data) {
      let reader = ByteReader(data)

      header = reader.read()

      structureSize = reader.read()
      sessionFlags = SessionFlags(rawValue: reader.read())
      securityBufferOffset = reader.read()
      securityBufferLength = reader.read()
      buffer = reader.read(from: Int(securityBufferOffset), count: Int(securityBufferLength))
    }
  }
}
