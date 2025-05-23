import Foundation

public enum Echo {
  public struct Request: Message.Request {
    public typealias Response = Echo.Response

    public let header: Header
    public let structureSize: UInt16
    public let reserved: UInt16

    public init(
      headerFlags: Header.Flags = [],
      messageId: UInt64,
      sessionId: UInt64
    ) {
      header = Header(
        creditCharge: 1,
        command: .echo,
        creditRequest: 0,
        flags: headerFlags,
        messageId: messageId,
        treeId: 0,
        sessionId: sessionId
      )

      structureSize = 4
      reserved = 0
    }

    public func encoded() -> Data {
      var data = Data()

      data += header.encoded()

      data += structureSize
      data += reserved

      return data
    }
  }

  public struct Response: Message.Response {
    public let header: Header
    public let structureSize: UInt16
    public let reserved: UInt16

    public init(data: Data) {
      let reader = ByteReader(data)

      header = reader.read()

      structureSize = reader.read()
      reserved = reader.read()
    }
  }
}
