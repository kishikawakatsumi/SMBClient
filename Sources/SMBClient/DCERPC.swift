import Foundation

enum DCERPC {
  struct Bind {
    let version: UInt8
    let minorVersion: UInt8
    let packetType: PacketType
    let flags: Flags
    let dataRepresentation: UInt32
    let fragLength: UInt16
    let authLength: UInt16
    let callID: UInt32
    let maxXmitFrag: UInt16
    let maxRecvFrag: UInt16
    let assocGroup: UInt32
    let context: ContextList
    let contextData: Data

    struct Flags: OptionSet {
      let rawValue: UInt8

      static let lastFragment = Flags(rawValue: 0x01)
      static let firstFragment = Flags(rawValue: 0x02)
      static let pendingCancel = Flags(rawValue: 0x04)
      static let reserved = Flags(rawValue: 0x08)
      static let concurrentMultiplexing = Flags(rawValue: 0x10)
      static let didNotExecute = Flags(rawValue: 0x20)
      static let maybe = Flags(rawValue: 0x40)
      static let objectUUID = Flags(rawValue: 0x80)
    }

    struct ContextList {
      let numberOfItems: UInt8
      let reserved: UInt8
      let reserved2: UInt16
      let items: [PresentationContext]

      init(items: [PresentationContext]) {
        self.numberOfItems = UInt8(items.count)
        self.reserved = 0
        self.reserved2 = 0
        self.items = items
      }

      init(contextID: UInt16, abstractSyntax: AbstractSyntax, transferSyntaxes: [TransferSyntax]) {
        self.numberOfItems = 1
        self.reserved = 0
        self.reserved2 = 0
        self.items = [PresentationContext(contextID: contextID, abstractSyntax: abstractSyntax, transferSyntaxes: transferSyntaxes)]
      }

      func encoded() -> Data {
        var data = Data()
        data += numberOfItems
        data += reserved
        data += reserved2
        for item in items {
          data += item.encoded()
        }

        return data
      }
    }

    struct PresentationContext {
      let contextID: UInt16
      let numberOfTransferSyntaxes: UInt8
      let reserved: UInt8 = 0
      let abstractSyntax: AbstractSyntax
      let transferSyntaxes: [TransferSyntax]

      init(contextID: UInt16, abstractSyntax: AbstractSyntax, transferSyntaxes: [TransferSyntax]) {
        self.contextID = contextID
        numberOfTransferSyntaxes = UInt8(transferSyntaxes.count)
        self.abstractSyntax = abstractSyntax
        self.transferSyntaxes = transferSyntaxes
      }

      func encoded() -> Data {
        var data = Data()
        data += contextID
        data += numberOfTransferSyntaxes
        data += reserved
        data += abstractSyntax.encoded()
        for transferSyntax in transferSyntaxes {
          data += transferSyntax.encoded()
        }

        return data
      }
    }

    struct AbstractSyntax {
      let interfaceUUID: Data
      let interfaceVersion: UInt16
      let interfaceMinorVersion: UInt16

      init() {
        // Interface: SRVSVC UUID: 4b324fc8-1670-01d3-1278-5a47bf6ee188
        // interfaceUUID = Data([0xC8, 0x4F, 0x32, 0x4B, 0x70, 0x16, 0xD3, 0x01, 0x12, 0x78, 0x5A, 0x47, 0xBF, 0x6E, 0xE1, 0x88])
        interfaceUUID = UUID(uuidString: "c84f324b-7016-d301-1278-5a47bf6ee188")!.data
        interfaceVersion = 3
        interfaceMinorVersion = 0
      }

      func encoded() -> Data {
        var data = Data()
        data += interfaceUUID
        data += interfaceVersion
        data += interfaceMinorVersion

        return data
      }
    }

    struct TransferSyntax {
      let interfaceUUID: Data
      let interfaceVersion: UInt32

      init() {
        // Transfer Syntax: 32bit NDR UUID:8a885d04-1ceb-11c9-9fe8-08002b104860
        // interfaceUUID = Data([0x04, 0x5D, 0x88, 0x8A, 0xEB, 0x1C, 0xC9, 0x11, 0x9F, 0xE8, 0x08, 0x00, 0x2B, 0x10, 0x48, 0x60])
        interfaceUUID = UUID(uuidString: "045d888a-eb1c-c911-9fe8-08002b104860")!.data
        interfaceVersion = 2
      }

      func encoded() -> Data {
        var data = Data()
        data += interfaceUUID
        data += interfaceVersion

        return data
      }
    }

    init(callID: UInt32, context: ContextList) {
      version = 5
      minorVersion = 0
      packetType = .bind
      flags = [.firstFragment, .lastFragment]
      dataRepresentation = 0x10
      let contextData = context.encoded()
      fragLength = UInt16(truncatingIfNeeded: 1 + 1 + 1 + 1 + 4 + 2 + 2 + 4 + 2 + 2 + 4 + contextData.count)
      authLength = 0
      self.callID = callID
      maxXmitFrag = 0xFFFF
      maxRecvFrag = 0xFFFF
      assocGroup = 0
      self.context = context
      self.contextData = contextData
    }

    func encoded() -> Data {
      var data = Data()
      data += version
      data += minorVersion
      data += packetType.rawValue
      data += flags.rawValue
      data += dataRepresentation
      data += fragLength
      data += authLength
      data += callID
      data += maxXmitFrag
      data += maxRecvFrag
      data += assocGroup
      data += contextData

      return data
    }
  }

  struct BindAck {
    let version: UInt8
    let minorVersion: UInt8
    let packetType: PacketType
    let flags: Bind.Flags
    let dataRepresentation: UInt32
    let fragLength: UInt16
    let authLength: UInt16
    let callID: UInt32
    let maxRecvFrag: UInt16
    let assocGroup: UInt32
    let secondaryAddress: UInt16
    let context: Bind.ContextList
    let contextData: Data

    init(callID: UInt32, context: Bind.ContextList) {
      self.version = 5
      self.minorVersion = 0
      self.packetType = .bindAck
      self.flags = [.firstFragment, .lastFragment]
      self.dataRepresentation = 0x10
      let contextData = context.encoded()
      self.fragLength = UInt16(truncatingIfNeeded: 1 + 1 + 1 + 1 + 4 + 2 + 2 + 4 + 2 + 4 + 2 + contextData.count)
      self.authLength = 0
      self.callID = callID
      self.maxRecvFrag = 0xFFFF
      self.assocGroup = 0
      self.secondaryAddress = 0
      self.context = context
      self.contextData = contextData
    }

    func encoded() -> Data {
      var data = Data()
      data += version
      data += minorVersion
      data += packetType.rawValue
      data += flags.rawValue
      data += dataRepresentation
      data += fragLength
      data += authLength
      data += callID
      data += maxRecvFrag
      data += assocGroup
      data += secondaryAddress
      data += contextData

      return data
    }
  }

  struct Request {
    let version: UInt8
    let minorVersion: UInt8
    let packetType: PacketType
    let flags: Bind.Flags
    let dataRepresentation: UInt32
    let fragLength: UInt16
    let authLength: UInt16
    let callID: UInt32
    let allocHint: UInt32
    let contextID: UInt16
    let opnum: Opnum
    let stub: Data

    init(callID: UInt32, opnum: Opnum, stub: Data) {
      version = 5
      minorVersion = 0
      packetType = .request
      flags = [.firstFragment, .lastFragment]
      dataRepresentation = 0x10
      self.fragLength = UInt16(truncatingIfNeeded: 1 + 1 + 1 + 1 + 4 + 2 + 2 + 4 + 4 + 2 + 2 + stub.count)
      authLength = 0
      self.callID = callID
      allocHint = 0
      contextID = 0
      self.opnum = opnum
      self.stub = stub
    }

    func encoded() -> Data {
      var data = Data()
      data += version
      data += minorVersion
      data += packetType.rawValue
      data += flags.rawValue
      data += dataRepresentation
      data += fragLength
      data += authLength
      data += callID
      data += allocHint
      data += contextID
      data += opnum.rawValue
      data += stub

      return data
    }
  }

  struct Response {
    let version: UInt8
    let minorVersion: UInt8
    let packetType: PacketType
    let flags: Bind.Flags
    let dataRepresentation: UInt32
    let fragLength: UInt16
    let authLength: UInt16
    let callID: UInt32
    let allocHint: UInt32
    let contextID: UInt16
    let cancelCount: UInt8
    let reserved: UInt8
    let stub: Data

    init(data: Data) {
      let byteStream = ByteReader(data)
      version = byteStream.read()
      minorVersion = byteStream.read()
      packetType = PacketType(rawValue: byteStream.read())!
      flags = Bind.Flags(rawValue: byteStream.read())
      dataRepresentation = byteStream.read()
      fragLength = byteStream.read()
      authLength = byteStream.read()
      callID = byteStream.read()
      allocHint = byteStream.read()
      contextID = byteStream.read()
      cancelCount = byteStream.read()
      reserved = byteStream.read()
      stub = byteStream.read(count: Int(fragLength) - 24)
    }
  }

  enum PacketType: UInt8 {
    case request = 0
    case ping = 1
    case response = 2
    case fault = 3
    case working = 4
    case nocall = 5
    case reject = 6
    case ack = 7
    case clCancel = 8
    case fack = 9
    case cancelAck = 10
    case bind = 11
    case bindAck = 12
    case bindNak = 13
    case alterContext = 14
    case alterContextResp = 15
    case shutdown = 17
    case coCancel = 18
    case orphaned = 19
  }

  enum Opnum: UInt16 {
    case opnum0NotUsedOnWire = 0
    case opnum1NotUsedOnWire = 1
    case opnum2NotUsedOnWire = 2
    case opnum3NotUsedOnWire = 3
    case opnum4NotUsedOnWire = 4
    case opnum5NotUsedOnWire = 5
    case opnum6NotUsedOnWire = 6
    case opnum7NotUsedOnWire = 7
    case netrConnectionEnum = 8
    case netrFileEnum = 9
    case netrFileGetInfo = 10
    case netrFileClose = 11
    case netrSessionEnum = 12
    case netrSessionDel = 13
    case netrShareAdd = 14
    case netrShareEnum = 15
    case netrShareGetInfo = 16
    case netrShareSetInfo = 17
    case netrShareDel = 18
    case netrShareDelSticky = 19
    case netrShareCheck = 20
    case netrServerGetInfo = 21
    case netrServerSetInfo = 22
    case netrServerDiskEnum = 23
    case netrServerStatisticsGet = 24
    case netrServerTransportAdd = 25
    case netrServerTransportEnum = 26
    case netrServerTransportDel = 27
    case netrRemoteTOD = 28
    case opnum29NotUsedOnWire = 29
    case netprPathType = 30
    case netprPathCanonicalize = 31
    case netprPathCompare = 32
    case netprNameValidate = 33
    case netprNameCanonicalize = 34
    case netprNameCompare = 35
    case netrShareEnumSticky = 36
    case netrShareDelStart = 37
    case netrShareDelCommit = 38
    case netrpGetFileSecurity = 39
    case netrpSetFileSecurity = 40
    case netrServerTransportAddEx = 41
    case opnum42NotUsedOnWire = 42
    case netrDfsGetVersion = 43
    case netrDfsCreateLocalPartition = 44
    case netrDfsDeleteLocalPartition = 45
    case netrDfsSetLocalVolumeState = 46
    case opnum47NotUsedOnWire = 47
    case netrDfsCreateExitPoint = 48
    case netrDfsDeleteExitPoint = 49
    case netrDfsModifyPrefix = 50
    case netrDfsFixLocalVolume = 51
    case netrDfsManagerReportSiteInfo = 52
    case netrServerTransportDelEx = 53
    case netrServerAliasAdd = 54
    case netrServerAliasEnum = 55
    case netrServerAliasDel = 56
    case netrShareDelEx = 57
  }

  struct NetShareEnum {
    let serverName: WStr
    let shareInfo: ShareInfo
    let preferredMaximumLength: UInt32
    let resumeHandle: UInt32

    init(serverName: String) {
      self.serverName = WStr(value: serverName)
      shareInfo = ShareInfo(
        level: 1,
        shareInfo: WStr(value: "")
      )
      preferredMaximumLength = 0xFFFFFFFF
      resumeHandle = 0
    }

    func encoded() -> Data {
      var data = Data()
      data += serverName.encoded()
      data += shareInfo.encoded()
      data += preferredMaximumLength
      data += resumeHandle

      return data
    }
  }

  struct ShareInfo {
    let level: UInt32
    let entriesRead: UInt32 = 1
    let shareInfo: WStr

    init(level: UInt32, shareInfo: WStr) {
      self.level = level
      self.shareInfo = shareInfo
    }

    func encoded() -> Data {
      var data = Data()
      data += level
      data += entriesRead
      data += shareInfo.encoded()

      return data
    }
  }

  struct WStr {
    let referentID: UInt32
    let maxCount: UInt32
    let offset: UInt32
    let actualCount: UInt32
    let value: String
    let valueData: Data
    let terminator: UInt16

    init(value: String) {
      referentID = 1
      let valueData = value.data(using: .utf16LittleEndian)!
      maxCount = UInt32(valueData.count / 2) + 1
      offset = 0
      actualCount = maxCount
      self.value = value
      self.valueData = valueData
      terminator = 0
    }

    init(referentID: UInt32, byteStream: ByteReader) {
      self.referentID = referentID
      maxCount = byteStream.read()
      offset = byteStream.read()
      actualCount = byteStream.read()
      let valueCount = Int(actualCount) * 2
      valueData = byteStream.read(count: valueCount)
      if valueCount % 4 != 0 {
        terminator = byteStream.read()
      } else {
        terminator = 0
      }
      let valueData = Data(valueData)[0..<valueData.count - 2]
      value = String(data: valueData, encoding: .utf16LittleEndian) ?? valueData.hex
    }

    func encoded() -> Data {
      var data = Data()
      data += referentID
      data += maxCount
      if valueData.isEmpty {
        data += offset
      } else {
        data += offset
        data += actualCount
        data += valueData
        let padding = Data(count: 4 - data.count % 4)
        data += padding
      }

      return data
    }
  }

  struct NDRLong {
    let referentID: UInt32
    let value: UInt32

    init(value: UInt32) {
      referentID = 1
      self.value = value
    }

    func encoded() -> Data {
      var data = Data()
      data += referentID
      data += value

      return data
    }
  }

  struct NetShareEnumResponse {
    let level: UInt32
    let shareCtr: UInt32
    let netShareCtr: NetShareCtr
    let shareInfo1: NetShareInfo1
    let padding: Data
    let totalEntries: UInt32
    let resumeHandle: UInt32
    let status: UInt32
    
    init(data: Data) {
      let byteStream = ByteReader(data)
      level = byteStream.read()
      shareCtr = byteStream.read()
      netShareCtr = NetShareCtr(
        refferentID: byteStream.read(),
        count: byteStream.read()
      )
      shareInfo1 = NetShareInfo1(byteStream: byteStream)
      padding = byteStream.read(count: byteStream.offset % 4 == 0 ? 0 : 4 - byteStream.offset % 4)
      totalEntries = byteStream.read()
      resumeHandle = byteStream.read()
      status = byteStream.read()
    }

    struct NetShareCtr {
      let refferentID: UInt32
      let count: UInt32
    }
    
    struct NetShareInfo1 {
      let refferentID: UInt32
      let count: UInt32
      let shareInfo: [ShareInfo1]
      
      init(byteStream: ByteReader) {
        refferentID = byteStream.read()
        count = byteStream.read()
        shareInfo = (0..<count)
          .map { _ in
            let nameRefferentID: UInt32 = byteStream.read()
            let type: UInt32 = byteStream.read()
            let commentRefferentID: UInt32 = byteStream.read()
            return (nameRefferentID, type, commentRefferentID)
          }
          .map { nameRefferentID, type, commentRefferentID in
            let name = WStr(referentID: nameRefferentID, byteStream: byteStream)
            let comment = WStr(referentID: commentRefferentID, byteStream: byteStream)
            return ShareInfo1(name: name, type: type, comment: comment)
          }
      }
    }
    
    struct ShareInfo1 {
      let name: WStr
      let type: UInt32
      let comment: WStr

      enum ShareType: UInt32 {
        case diskTree = 0x00000000
        case printQueue = 0x00000001
        case device = 0x00000002
        case IPC = 0x00000003
        case special = 0x80000000
        case temporary = 0x40000000
      }
    }
  }    
}
