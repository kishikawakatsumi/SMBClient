import Foundation

public enum Write {
  public struct Request {
    public let header: Header
    public let structureSize: UInt16
    public let dataOffset: UInt16
    public let length: UInt32
    public let offset: UInt64
    public let fileId: Data
    public let channel: UInt32
    public let remainingBytes: UInt32
    public let writeChannelInfoOffset: UInt16
    public let writeChannelInfoLength: UInt16
    public let flags: Flags
    public let buffer: Data

    public init(
      creditRequest: UInt16,
      messageId: UInt64,
      treeId: UInt32,
      sessionId: UInt64,
      fileId: Data,
      offset: UInt64,
      data: Data
    ) {
      header = Header(
        creditCharge: creditRequest,
        command: .write,
        creditRequest: creditRequest,
        flags: [],
        nextCommand: 0,
        messageId: messageId,
        treeId: treeId,
        sessionId: sessionId
      )
      structureSize = 49
      dataOffset = 112
      length = UInt32(data.count)
      self.offset = offset
      self.fileId = fileId
      channel = 0
      remainingBytes = 0
      writeChannelInfoOffset = 0
      writeChannelInfoLength = 0
      flags = []
      buffer = data
    }

    public func encoded() -> Data {
      var data = Data()
      data += header.encoded()
      data += structureSize
      data += dataOffset
      data += length
      data += offset
      data += fileId
      data += channel
      data += remainingBytes
      data += writeChannelInfoOffset
      data += writeChannelInfoLength
      data += flags.rawValue
      data += buffer
      return data
    }

    public struct Flags: OptionSet, Sendable {
      public let rawValue: UInt32

      public init(rawValue: UInt32) {
        self.rawValue = rawValue
      }

      public static let writeThrough = Flags(rawValue: 0x00000001)
      public static let writeUnbuffered = Flags(rawValue: 0x00000002)
    }
  }

  public struct Response {
    public let header: Header
    public let structureSize: UInt16
    public let reserved: UInt16
    public let count: UInt32
    public let remaining: UInt32
    public let writeChannelInfoOffset: UInt16
    public let writeChannelInfoLength: UInt16

    public init(data: Data) {
      let reader = ByteReader(data)

      header = reader.read()

      structureSize = reader.read()
      reserved = reader.read()
      count = reader.read()
      remaining = reader.read()
      writeChannelInfoOffset = reader.read()
      writeChannelInfoLength = reader.read()
    }
  }
}
