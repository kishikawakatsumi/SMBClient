import Foundation

public enum QueryInfo {
  public struct Request: Message.Request {
    public typealias Response = QueryInfo.Response

    public let header: Header
    public let structureSize: UInt16
    public let infoType: InfoType
    public let fileInfoClass: FileInfoClass
    public let outputBufferLength: UInt32
    public let inputBufferOffset: UInt16
    public let reserved: UInt16
    public let inputBufferLength: UInt32
    public let additionalInformation: UInt32
    public let flags: Flags
    public let fileId: Data
    public let buffer: Data

    public init(
      headerFlags: Header.Flags = [],
      messageId: UInt64,
      treeId: UInt32,
      sessionId: UInt64,
      infoType: InfoType,
      fileInfoClass: FileInfoClass,
      flags: Flags = [],
      fileId: Data
    ) {
      header = Header(
        creditCharge: 1,
        command: .queryInfo,
        creditRequest: 64,
        flags: headerFlags,
        messageId: messageId,
        treeId: treeId,
        sessionId: sessionId
      )

      structureSize = 41
      self.infoType = infoType
      self.fileInfoClass = fileInfoClass
      self.outputBufferLength = 1124
      self.inputBufferOffset = 0
      self.reserved = 0
      self.inputBufferLength = 0
      self.additionalInformation = 0
      self.flags = flags
      self.fileId = fileId
      self.buffer = Data()
    }

    public func encoded() -> Data {
      var data = Data()

      data += header.encoded()
      
      data += structureSize
      data += infoType.rawValue
      data += fileInfoClass.rawValue
      data += outputBufferLength
      data += inputBufferOffset
      data += reserved
      data += inputBufferLength
      data += additionalInformation
      data += flags.rawValue
      data += fileId
      data += buffer
      
      return data
    }
  }

  public struct Response: Message.Response {
    public let header: Header
    public let structureSize: UInt16
    public let outputBufferOffset: UInt16
    public let outputBufferLength: UInt32
    public let buffer: Data

    public init(data: Data) {
      let reader = ByteReader(data)
      
      header = reader.read()
      structureSize = reader.read()
      outputBufferOffset = reader.read()
      outputBufferLength = reader.read()
      buffer = reader.read(count: Int(outputBufferLength))
    }
  }

  public struct Flags: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    public static let restartScans = Flags(rawValue: 0x00000001)
    public static let returnSingleEntry = Flags(rawValue: 0x00000002)
    public static let indexSpecified = Flags(rawValue: 0x00000004)
  }
}
