import Foundation

public enum QueryDirectory {
  public struct Request {
    public let header: Header
    public let structureSize: UInt16
    public let fileInformationClass: FileInformationClass
    public let flags: Flags
    public let fileIndex: UInt32
    public let fileId: Data
    public let fileNameOffset: UInt16
    public let fileNameLength: UInt16
    public let outputBufferLength: UInt32
    public let buffer: Data

    public init(
      headerFlags: Header.Flags = [],
      messageId: UInt64,
      treeId: UInt32,
      sessionId: UInt64,
      fileInformationClass: FileInformationClass,
      flags: Flags = [.restartScans],
      fileId: Data,
      fileName: String
    ) {
      header = Header(
        creditCharge: 1,
        command: .queryDirectory,
        creditRequest: 64,
        flags: headerFlags,
        nextCommand: 0,
        messageId: messageId,
        treeId: treeId,
        sessionId: sessionId
      )

      structureSize = 33
      self.fileInformationClass = fileInformationClass
      self.flags = flags
      fileIndex = 0
      self.fileId = fileId

      let fileNameData = fileName.encoded()
      fileNameOffset = 96
      fileNameLength = UInt16(truncatingIfNeeded: fileNameData.count)

      outputBufferLength = 0x00010000
      buffer = fileNameData + Data(count: 2)
    }

    public func encoded() -> Data {
      var data = Data()

      data += header.encoded()
      data += structureSize
      data += fileInformationClass.rawValue
      data += flags.rawValue
      data += fileIndex
      data += fileId
      data += fileNameOffset
      data += fileNameLength
      data += outputBufferLength
      data += buffer

      return data
    }
  }

  public struct Response {
    public let header: Header
    public let structureSize: UInt16
    public let outputBufferOffset: UInt16
    public let outputBufferLength: UInt32
    public let buffer: Data
    public let files: [FileIdBothDirectoryInformation]

    public init(data: Data) {
      let reader = ByteReader(data)

      header = reader.read()

      structureSize = reader.read()
      outputBufferOffset = reader.read()
      outputBufferLength = reader.read()
      buffer = data[UInt32(outputBufferOffset)..<UInt32(outputBufferOffset) + outputBufferLength]

      var files = [FileIdBothDirectoryInformation]()
      if outputBufferLength > 0 {
        var data = Data(buffer)
        repeat {
          let fileInformation = FileIdBothDirectoryInformation(data: data)
          files.append(fileInformation)
          data = Data(data[(fileInformation.nextEntryOffset)...])
        } while files.last!.nextEntryOffset != 0
      }

      self.files = files
    }
  }

  public enum FileInformationClass: UInt8 {
    case fileDirectoryInformation = 0x01
    case fileFullDirectoryInformation = 0x02
    case fileIdFullDirectoryInformation = 0x26
    case fileBothDirectoryInformation = 0x03
    case fileIdBothDirectoryInformation = 0x25
    case fileNamesInformation = 0x0C
    case fileIdExtdDirectoryInformation = 0x3C
    case fileInfomationClass_Reserved = 0x64
  }

  public struct Flags: OptionSet, Sendable {
    public let rawValue: UInt8

    public init(rawValue: UInt8) {
      self.rawValue = rawValue
    }

    public static let restartScans = Flags(rawValue: 0x01)
    public static let returnSingleEntry = Flags(rawValue: 0x02)
    public static let indexSpecified = Flags(rawValue: 0x04)
    public static let reopen = Flags(rawValue: 0x10)
  }

  public struct FileIdBothDirectoryInformation {
    public let nextEntryOffset: UInt32
    public let fileIndex: UInt32
    public let creationTime: UInt64
    public let lastAccessTime: UInt64
    public let lastWriteTime: UInt64
    public let changeTime: UInt64
    public let endOfFile: UInt64
    public let allocationSize: UInt64
    public let fileAttributes: FileAttributes
    public let fileNameLength: UInt32
    public let eaSize: UInt32
    public let shortNameLength: UInt8
    public let reserved: UInt8
    public let shortName: String
    public let reserved2: UInt16
    public let fileId: Data
    public let fileName: String

    public init(data: Data) {
      let reader = ByteReader(data)

      nextEntryOffset = reader.read()
      fileIndex = reader.read()
      creationTime = reader.read()
      lastAccessTime = reader.read()
      lastWriteTime = reader.read()
      changeTime = reader.read()
      endOfFile = reader.read()
      allocationSize = reader.read()
      fileAttributes = FileAttributes(rawValue: reader.read())
      fileNameLength = reader.read()
      eaSize = reader.read()
      shortNameLength = reader.read()
      reserved = reader.read()

      let shortNameData = reader.read(count: 24)
      shortName = String(data: shortNameData, encoding: .utf16LittleEndian) ?? shortNameData.hex

      reserved2 = reader.read()
      fileId = reader.read(count: 8)

      let fileNameData = reader.read(count: Int(fileNameLength))
      fileName = String(data: fileNameData, encoding: .utf16LittleEndian) ?? fileNameData.hex
    }
  }
}
