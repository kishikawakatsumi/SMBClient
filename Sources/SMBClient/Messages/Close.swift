import Foundation

public enum Close {
  public struct Request {
    public let header: Header
    public let structureSize: UInt16
    public let flags: Flags
    public let reserved: UInt32
    public let fileId: Data

    public init(
      creditRequest: UInt16 = 1,
      flags headerFlags: Header.Flags = [],
      messageId: UInt64,
      treeId: UInt32,
      sessionId: UInt64,
      fileId: Data
    ) {
      header = Header(
        creditCharge: creditRequest,
        command: .close,
        creditRequest: creditRequest,
        flags: headerFlags,
        nextCommand: 0,
        messageId: messageId,
        treeId: treeId,
        sessionId: sessionId
      )

      structureSize = 24
      flags = .postQueryAttrib
      reserved = 0
      self.fileId = fileId
    }

    public func encoded() -> Data {
      var data = Data()
      data += header.encoded()
      data += structureSize
      data += flags.rawValue
      data += reserved
      data += fileId
      return data
    }
  }

  public struct Response {
    public let header: Header
    public let structureSize: UInt16
    public let flags: UInt16
    public let reserved: UInt32
    public let creationTime: UInt64
    public let lastAccessTime: UInt64
    public let lastWriteTime: UInt64
    public let changeTime: UInt64
    public let allocationSize: UInt64
    public let endOfFile: UInt64
    public let fileAttributes: UInt32

    public init(data: Data) {
      let reader = ByteReader(data)
      header = reader.read()
      structureSize = reader.read()
      flags = reader.read()
      reserved = reader.read()
      creationTime = reader.read()
      lastAccessTime = reader.read()
      lastWriteTime = reader.read()
      changeTime = reader.read()
      allocationSize = reader.read()
      endOfFile = reader.read()
      fileAttributes = reader.read()
    }
  }

  public enum Flags: UInt16 {
    case postQueryAttrib = 0x0001
  }
}
