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
      creditCharge: UInt16 = 1,
      headerFlags: Header.Flags = [],
      messageId: UInt64,
      treeId: UInt32,
      sessionId: UInt64,
      fileInformationClass: FileInformationClass,
      flags: Flags = [.restartScans],
      fileId: Data,
      fileName: String,
      outputBufferLength: UInt32 = 65535
    ) {
      header = Header(
        creditCharge: creditCharge,
        command: .queryDirectory,
        creditRequest: 256,
        flags: headerFlags,
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

      self.outputBufferLength = outputBufferLength
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

    public init(data: Data) {
      let reader = ByteReader(data)

      header = reader.read()

      structureSize = reader.read()
      outputBufferOffset = reader.read()
      outputBufferLength = reader.read()
      buffer = data[UInt32(outputBufferOffset)..<UInt32(outputBufferOffset) + outputBufferLength]
    }

    public func files() -> [FileDirectoryInformation] {
      var files = [FileDirectoryInformation]()
      if outputBufferLength > 0 {
        var data = Data(buffer)
        repeat {
          let fileInformation = FileDirectoryInformation(data: data)
          files.append(fileInformation)
          data = Data(data[(fileInformation.nextEntryOffset)...])
        } while files.last!.nextEntryOffset != 0
      }

      return files
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
}
