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

    public enum InfoType: UInt8 {
      case file = 0x01
      case fileSystem = 0x02
      case security = 0x03
      case quota = 0x04
    }

    public enum FileSystemInfoClass: UInt8 {
      case fileFsVolumeInformation = 0x01
      case fileFsLabelInformation = 0x02
      case fileFsSizeInformation = 0x03
      case fileFsDeviceInformation = 0x04
      case fileFsAttributeInformation = 0x05
      case fileFsControlInformation = 0x06
      case fileFsFullSizeInformation = 0x07
      case fileFsObjectIdInformation = 0x08
      case fileFsDriverPathInformation = 0x09
      case fileFsVolumeFlagsInformation = 0x0A
      case fileFsSectorSizeInformation = 0x0B
    }

    public struct SecurityDescriptor: OptionSet {
      public let rawValue: UInt8

      public static let owner = SecurityDescriptor(rawValue: 0x00000001)
      public static let group = SecurityDescriptor(rawValue: 0x00000002)
      public static let dacl = SecurityDescriptor(rawValue: 0x00000004)
      public static let sacl = SecurityDescriptor(rawValue: 0x00000008)
      public static let label = SecurityDescriptor(rawValue: 0x00000010)
      public static let attribute = SecurityDescriptor(rawValue: 0x00000020)
      public static let scope = SecurityDescriptor(rawValue: 0x00000040)
      public static let backup = SecurityDescriptor(rawValue: 0x00000080)
    }

    public struct Flags: OptionSet {
      public let rawValue: UInt32

      public static let replaceIfExists = Flags(rawValue: 0x00000001)
      public static let advanceOnly = Flags(rawValue: 0x00000002)
    }

    public init(
      creditRequest: UInt16 = 1,
      flags: Header.Flags = [],
      messageId: UInt64,
      treeId: UInt32,
      sessionId: UInt64,
      fileId: Data,
      infoType: InfoType,
      fileInformation: FileInformationClass
    ) {
      header = Header(
        creditCharge: creditRequest,
        command: .setInfo,
        creditRequest: creditRequest,
        flags: flags,
        nextCommand: 0,
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
      let byteReader = ByteReader(data)
      header = Header(data: data)
      structureSize = byteReader.read()
    }
  }
}
