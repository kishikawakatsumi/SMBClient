import Foundation

enum SetInfo {
  public struct Request {
    public let header: Header
    public let structureSize: UInt16
    public let infoType: InfoType
    public let fileInfoClass: FileInfoClass
    public let bufferLength: UInt32
    public let bufferOffset: UInt16
    public let reserved: UInt16
    public let additionalInformation: UInt32
    public let fileId: Data
    public let buffer: Data

    public struct Flags: OptionSet {
      public let rawValue: UInt32

      public static let replaceIfExists = Flags(rawValue: 0x00000001)
      public static let advanceOnly = Flags(rawValue: 0x00000002)
    }

    public init(
      headerFlags: Header.Flags = [],
      messageId: UInt64,
      treeId: UInt32,
      sessionId: UInt64,
      fileId: Data,
      infoType: InfoType,
      fileInformation: FileInformationClass
    ) {
      header = Header(
        creditCharge: 1,
        command: .setInfo,
        creditRequest: 0,
        flags: headerFlags,
        messageId: messageId,
        treeId: treeId,
        sessionId: sessionId
      )

      structureSize = 33
      self.infoType = infoType
      self.fileInfoClass = fileInformation.infoClass
      let buffer = fileInformation.encoded()
      bufferLength = UInt32(buffer.count)
      bufferOffset = 96
      reserved = 0
      additionalInformation = 0
      self.fileId = fileId
      self.buffer = buffer
    }

    public func encoded() -> Data {
      var data = Data()

      data += header.encoded()
      data += structureSize
      data += infoType.rawValue
      data += fileInfoClass.rawValue
      data += bufferLength
      data += bufferOffset
      data += reserved
      data += additionalInformation
      data += fileId
      data += buffer

      return data
    }
  }

  public struct Response {
    public let header: Header
    public let structureSize: UInt16

    public init(data: Data) {
      let reader = ByteReader(data)
      
      header = reader.read()
      structureSize = reader.read()
    }
  }
}
