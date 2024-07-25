import Foundation

public enum Read {
  public struct Request {
    public let header: Header
    public let structureSize: UInt16
    public let padding: UInt8
    public let flags: UInt8
    public let length: UInt32
    public let offset: UInt64
    public let fileId: Data
    public let minimumCount: UInt32
    public let channel: UInt32
    public let remainingBytes: UInt32
    public let readChannelInfoOffset: UInt16
    public let readChannelInfoLength: UInt16
    public let buffer: Data

    public init(
      creditCharge: UInt16,
      headerFlags: Header.Flags = [],
      messageId: UInt64,
      treeId: UInt32,
      sessionId: UInt64,
      fileId: Data,
      offset: UInt64,
      length: UInt32
    ) {
      header = Header(
        creditCharge: creditCharge,
        command: .read,
        creditRequest: 256,
        flags: headerFlags,
        messageId: messageId,
        treeId: treeId,
        sessionId: sessionId
      )

      structureSize = 49
      padding = 0
      flags = 0
      self.length = length
      self.offset = offset
      self.fileId = fileId
      minimumCount = 0
      channel = 0
      remainingBytes = 0
      readChannelInfoOffset = 0
      readChannelInfoLength = 0
      buffer = Data(count: 1)
    }

    public func encoded() -> Data {
      var data = Data()

      data += header.encoded()

      data += structureSize
      data += padding
      data += flags
      data += length
      data += offset
      data += fileId
      data += minimumCount
      data += channel
      data += remainingBytes
      data += readChannelInfoOffset
      data += readChannelInfoLength
      data += buffer

      return data
    }
  }

  public struct Response {
    public let header: Header
    public let structureSize: UInt16
    public let dataOffset: UInt8
    public let reserved: UInt8
    public let dataLength: UInt32
    public let dataRemaining: UInt32
    public let reserved2: UInt32
    public let buffer: Data

    public enum ReadFlag: UInt32 {
      case responseNone = 0x00000000
      case responseRdmaTransform = 0x00000001
    }

    public init(data: Data) {
      let reader = ByteReader(data)

      header = reader.read()

      structureSize = reader.read()

      if header.status != 0xc0000011 {
        dataOffset = reader.read()
        reserved = reader.read()
        dataLength = reader.read()
        dataRemaining = reader.read()
        reserved2 = reader.read()
        buffer = reader.read(from: Int(dataOffset), count: Int(dataLength))
      } else {
        dataOffset = 0
        reserved = 0
        dataLength = 0
        dataRemaining = 0
        reserved2 = 0
        buffer = Data()
      }
    }
  }

  public enum Flags: UInt8 {
    case readUnbuffered = 0x01
    case requestCompressed = 0x02
  }

  public enum Channel: UInt32 {
    case none = 0x00000000
    case rdmaV1 = 0x00000001
    case rdmaV1Invalidate = 0x00000002
  }
}
