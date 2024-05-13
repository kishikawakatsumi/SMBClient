import Foundation

enum QueryInfo {
  public struct Request {
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

      public static let restartScans = Flags(rawValue: 0x00000001)
      public static let returnSingleEntry = Flags(rawValue: 0x00000002)
      public static let indexSpecified = Flags(rawValue: 0x00000004)
    }

    public init(
      flags: Header.Flags = [],
      messageId: UInt64,
      treeId: UInt32,
      sessionId: UInt64,
      infoType: InfoType,
      fileInfoClass: FileInfoClass,
      outputBufferLength: UInt32,
      inputBufferOffset: UInt16,
      reserved: UInt16,
      inputBufferLength: UInt32,
      additionalInformation: UInt32,
      flags2: Flags = [.restartScans],
      fileId: Data,
      buffer: Data
    ) {
      header = Header(
        creditCharge: 1,
        command: .queryInfo,
        creditRequest: 64,
        flags: flags,
        nextCommand: 0,
        messageId: messageId,
        treeId: treeId,
        sessionId: sessionId
      )

      structureSize = 41
      self.infoType = infoType
      self.fileInfoClass = fileInfoClass
      self.outputBufferLength = outputBufferLength
      self.inputBufferOffset = inputBufferOffset
      self.reserved = reserved
      self.inputBufferLength = inputBufferLength
      self.additionalInformation = additionalInformation
      self.flags = flags2
      self.fileId = fileId
      self.buffer = buffer
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
}
