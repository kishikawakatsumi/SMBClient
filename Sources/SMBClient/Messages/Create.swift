import Foundation

public enum Create {
  public struct Request {
    public private(set) var header: Header
    public let structureSize: UInt16
    public let securityFlags: UInt8
    public let requestedOplockLevel: OplockLevel
    public let impersonationLevel: ImpersonationLevel
    public let smbCreateFlags: UInt64
    public let reserved: UInt64
    public let desiredAccess: FilePipePrinterAccessMask
    public let fileAttributes: FileAttributes
    public let shareAccess: ShareAccess
    public let createDisposition: CreateDisposition
    public let createOptions: CreateOptions
    public let nameOffset: UInt16
    public let nameLength: UInt16
    public let createContextsOffset: UInt32
    public let createContextsLength: UInt32
    public let buffer: Data

    public init(
      messageId: UInt64,
      treeId: UInt32,
      sessionId: UInt64,
      desiredAccess: FilePipePrinterAccessMask,
      fileAttributes: FileAttributes,
      shareAccess: ShareAccess,
      createDisposition: CreateDisposition,
      createOptions: CreateOptions,
      name: String
    ) {
      self.header = Header(
        creditCharge: 1,
        command: .create,
        creditRequest: 256,
        flags: [],
        nextCommand: 0,
        messageId: messageId,
        treeId: treeId,
        sessionId: sessionId
      )
      structureSize = 57
      securityFlags = 0
      requestedOplockLevel = .none
      impersonationLevel = .impersonation
      smbCreateFlags = 0
      reserved = 0
      self.desiredAccess = desiredAccess
      self.fileAttributes = fileAttributes
      self.shareAccess = shareAccess
      self.createDisposition = createDisposition
      self.createOptions = createOptions
      nameOffset = 120
      let nameData = name.data(using: .utf16LittleEndian)!
      nameLength = UInt16(truncatingIfNeeded: nameData.count)
      createContextsOffset = 0
      createContextsLength = 0
      buffer = nameData
    }

    public func encoded() -> Data {
      var data = Data()
      data += header.encoded()
      data += structureSize
      data += securityFlags
      data += requestedOplockLevel.rawValue
      data += impersonationLevel.rawValue
      data += smbCreateFlags
      data += reserved
      data += desiredAccess.rawValue
      data += fileAttributes.rawValue
      data += shareAccess.rawValue
      data += createDisposition.rawValue
      data += createOptions.rawValue
      data += nameOffset
      data += nameLength
      data += createContextsOffset
      data += createContextsLength
      data += buffer
      return data
    }

    public enum OplockLevel: UInt8 {
      case none = 0x00
      case ii = 0x01
      case exclusive = 0x08
      case batch = 0x09
      case lease = 0xFF
    }

    public enum ImpersonationLevel: UInt32 {
      case anonymous = 0x00000000
      case identification = 0x00000001
      case impersonation = 0x00000002
      case delegation = 0x00000003
    }

    public struct ShareAccess: OptionSet {
      public let rawValue: UInt32

      public init(rawValue: UInt32) {
        self.rawValue = rawValue
      }

      public static let read = ShareAccess(rawValue: 0x00000001)
      public static let write = ShareAccess(rawValue: 0x00000002)
      public static let delete = ShareAccess(rawValue: 0x00000004)
    }

    public enum CreateDisposition: UInt32 {
      case supersede = 0x00000000
      case open = 0x00000001
      case create = 0x00000002
      case openIf = 0x00000003
      case overwrite = 0x00000004
      case overwriteIf = 0x00000005
    }

    public struct CreateOptions: OptionSet {
      public let rawValue: UInt32

      public init(rawValue: UInt32) {
        self.rawValue = rawValue
      }

      public static let directoryFile = CreateOptions(rawValue: 0x00000001)
      public static let writeThrough = CreateOptions(rawValue: 0x00000002)
      public static let sequentialOnly = CreateOptions(rawValue: 0x00000004)
      public static let noIntermediateBuffering = CreateOptions(rawValue: 0x00000008)
      public static let synchronousIoAlert = CreateOptions(rawValue: 0x00000010)
      public static let synchronousIoNonAlert = CreateOptions(rawValue: 0x00000020)
      public static let nonDirectoryFile = CreateOptions(rawValue: 0x00000040)
      public static let completeIfOplocked = CreateOptions(rawValue: 0x00000100)
      public static let noEaKnowledge = CreateOptions(rawValue: 0x00000200)
      public static let randomAccess = CreateOptions(rawValue: 0x00000800)
      public static let deleteOnClose = CreateOptions(rawValue: 0x00001000)
      public static let openByFileId = CreateOptions(rawValue: 0x00002000)
      public static let openForBackupIntent = CreateOptions(rawValue: 0x00004000)
      public static let noCompression = CreateOptions(rawValue: 0x00008000)
      public static let openRemoteInstance = CreateOptions(rawValue: 0x00000400)
      public static let requiringOplock = CreateOptions(rawValue: 0x00010000)
      public static let disallowExclusive = CreateOptions(rawValue: 0x00020000)
      public static let reserveOpfilter = CreateOptions(rawValue: 0x00100000)
      public static let openReparsePoint = CreateOptions(rawValue: 0x00200000)
      public static let openNoRecall = CreateOptions(rawValue: 0x00400000)
      public static let openForFreeSpaceQuery = CreateOptions(rawValue: 0x00800000)
    }
  }

  public struct Response {
    public let header: Header
    public let structureSize: UInt16
    public let oplockLevel: UInt8
    public let flags: Flags
    public let createAction: UInt32
    public let creationTime: UInt64
    public let lastAccessTime: UInt64
    public let lastWriteTime: UInt64
    public let changeTime: UInt64
    public let allocationSize: UInt64
    public let endOfFile: UInt64
    public let fileAttributes: FileAttributes
    public let reserved2: UInt32
    public let fileId: Data
    public let createContextsOffset: UInt32
    public let createContextsLength: UInt32
    public let buffer: Data

    public enum OplockLevel: UInt8 {
      case none = 0x00
      case ii = 0x01
      case exclusive = 0x08
      case batch = 0x09
      case lease = 0xFF
    }

    public struct Flags: OptionSet {
      public let rawValue: UInt8

      public init(rawValue: UInt8) {
        self.rawValue = rawValue
      }

      public static let releasePoint = Flags(rawValue: 0x00000001)
    }

    public enum CreateAction: UInt32 {
      case superseded = 0x00000000
      case opened = 0x00000001
      case created = 0x00000002
      case overwritten = 0x00000003
    }

    public init(data: Data) {
      let reader = ByteReader(data)

      header = reader.read()

      structureSize = reader.read()
      oplockLevel = reader.read()
      flags = Flags(rawValue: reader.read())
      createAction = reader.read()
      creationTime = reader.read()
      lastAccessTime = reader.read()
      lastWriteTime = reader.read()
      changeTime = reader.read()
      allocationSize = reader.read()
      endOfFile = reader.read()
      fileAttributes = FileAttributes(rawValue: reader.read())
      reserved2 = reader.read()
      fileId = reader.read(count: 16)
      createContextsOffset = reader.read()
      createContextsLength = reader.read()
      if createContextsOffset > 0 {
        buffer = reader.read(from: Int(createContextsOffset), count: Int(createContextsLength))
      } else {
        buffer = Data()
      }
    }
  }
}
