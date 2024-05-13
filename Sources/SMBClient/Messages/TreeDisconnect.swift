import Foundation

public enum TreeDisconnect {
  public struct Request {
    public let header: Header
    public let structureSize: UInt16
    public let reserved: UInt16
    
    public init(messageId: UInt64, treeId: UInt32, sessionId: UInt64) {
      header = Header(
        creditCharge: 1,
        command: .treeDisconnect,
        creditRequest: 64,
        flags: [],
        nextCommand: 0,
        messageId: messageId,
        treeId: treeId,
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

  public struct Response {
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
