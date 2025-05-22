import Foundation

public enum Flush {
  public struct Request: Message.Request {
    public typealias Response = Flush.Response

    public let header: Header
    public let structureSize: UInt16
    public let reserved1: UInt16
    public let reserved2: UInt32
    public let fileId: Data

    public init(
      headerFlags: Header.Flags = [],
      messageId: UInt64,
      treeId: UInt32,
      sessionId: UInt64,
      fileId: Data
    ) {
      header = Header(
        creditCharge: 1,
        command: .flush,
        creditRequest: 0,
        flags: headerFlags,
        messageId: messageId,
        treeId: treeId,
        sessionId: sessionId
      )

      structureSize = 24
      reserved1 = 0
      reserved2 = 0
      self.fileId = fileId
    }

    public func encoded() -> Data {
      var data = Data()

      data += header.encoded()
      data += structureSize
      data += reserved1
      data += reserved2
      data += fileId

      return data
    }
  }

  public struct Response: Message.Response {
    public let header: Header
    public let structureSize: UInt16
    public let reserved: UInt16

    public init(data: Data) {
      let reader = ByteReader(data)

      header = Header(data: data)
      structureSize = reader.read()
      reserved = reader.read()
    }
  }
}
