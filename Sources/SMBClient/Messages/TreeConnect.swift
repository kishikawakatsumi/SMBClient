import Foundation

public enum TreeConnect {
  public struct Request: Message.Request {
    public typealias Response = TreeConnect.Response

    public let header: Header
    public let structureSize: UInt16
    public let reserved: UInt16
    public let pathOffset: UInt16
    public let pathLength: UInt16
    public let buffer: Data

    public init(
      headerFlags: Header.Flags = [],
      messageId: UInt64,
      sessionId: UInt64,
      path: String
    ) {
      header = Header(
        creditCharge: 1,
        command: .treeConnect,
        creditRequest: 64,
        flags: headerFlags,
        messageId: messageId,
        treeId: 0,
        sessionId: sessionId
      )

      structureSize = 9
      reserved = 0
      
      let pathData = path.encoded()
      pathOffset = 72
      pathLength = UInt16(truncatingIfNeeded: pathData.count)
      self.buffer = pathData
    }

    public func encoded() -> Data {
      var data = Data()

      data += header.encoded()
      data += structureSize
      data += reserved
      data += pathOffset
      data += pathLength
      data += buffer

      return data
    }
  }

  public struct Response: Message.Response {
    public let header: Header
    public let structureSize: UInt16
    public let shareType: UInt8
    public let reserved: UInt8
    public let shareFlags: ShareFlags
    public let capabilities: Capabilities
    public let maximalAccess: UInt32

    public init(data: Data) {
      let reader = ByteReader(data)

      header = reader.read()

      structureSize = reader.read()
      shareType = reader.read()
      reserved = reader.read()
      shareFlags = ShareFlags(rawValue: reader.read())
      capabilities = Capabilities(rawValue: reader.read())
      maximalAccess = reader.read()
    }
  }

  public struct Flags: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
      self.rawValue = rawValue
    }

    static let clusterReconnect = Flags(rawValue: 0x0001)
    static let redirectToOwner = Flags(rawValue: 0x0002)
    static let extensionPresent = Flags(rawValue: 0x0004)
  }

  public enum ShareType: UInt8 {
    case disk = 0x01
    case pipe = 0x02
    case print = 0x03
  }

  public struct ShareFlags: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    public static let manualCaching = ShareFlags([]) // 0x00000000
    public static let autoCaching = ShareFlags(rawValue: 0x00000010)
    public static let vdoCaching = ShareFlags(rawValue: 0x00000020)
    public static let noCaching = ShareFlags(rawValue: 0x00000030)
    public static let dfs = ShareFlags(rawValue: 0x00000001)
    public static let dfsRoot = ShareFlags(rawValue: 0x00000002)
    public static let restrectExclusiveOpens = ShareFlags(rawValue: 0x00000100)
    public static let forceSharedDelete = ShareFlags(rawValue: 0x00000200)
    public static let allowNamespaceCaching = ShareFlags(rawValue: 0x00000400)
    public static let accessBasedDirectoryEnum = ShareFlags(rawValue: 0x00000800)
    public static let forceLevelIIOplock = ShareFlags(rawValue: 0x00001000)
    public static let enableHashV1 = ShareFlags(rawValue: 0x00002000)
    public static let enableHashV2 = ShareFlags(rawValue: 0x00004000)
    public static let encryptData = ShareFlags(rawValue: 0x00008000)
    public static let identityRemoting = ShareFlags(rawValue: 0x00040000)
    public static let compressData = ShareFlags(rawValue: 0x00100000)
    public static let isolatedTransport = ShareFlags(rawValue: 0x00200000)
  }

  public struct Capabilities: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    public static let dfs = Capabilities(rawValue: 0x00000008)
    public static let continuousAvailability = Capabilities(rawValue: 0x00000010)
    public static let scaleout = Capabilities(rawValue: 0x00000020)
    public static let cluster = Capabilities(rawValue: 0x00000040)
    public static let asymmetric = Capabilities(rawValue: 0x00000080)
    public static let redirectToOwner = Capabilities(rawValue: 0x00000100)
  }
}
