import Foundation

enum DCERPC {
  struct CommonFields {
    let version: UInt8
    let minorVersion: UInt8
    let packetType: UInt8
    let flags: Flags
    let dataRepresentation: UInt32
    let fragLength: UInt16
    let authLength: UInt16
    let callID: UInt32

    init(packetType: PacketType, callID: UInt32, data: Data) {
      version = 5
      minorVersion = 0
      self.packetType = packetType.rawValue
      flags = [.firstFragment, .lastFragment]
      dataRepresentation = 0x10
      // Common Fields(16) + max_xmit_frag(2) max_recv_frag(2) assoc_group_id(4) == 24
      fragLength = UInt16(truncatingIfNeeded: 24 + data.count)
      authLength = 0
      self.callID = callID
    }

    init(data: Data) {
      let reader = ByteReader(data)

      version = reader.read()
      minorVersion = reader.read()
      packetType = reader.read()
      flags = Flags(rawValue: reader.read())
      dataRepresentation = reader.read()
      fragLength = reader.read()
      authLength = reader.read()
      callID = reader.read()
    }

    func encoded() -> Data {
      var data = Data()
      data += version
      data += minorVersion
      data += packetType
      data += flags.rawValue
      data += dataRepresentation
      data += fragLength
      data += authLength
      data += callID

      return data
    }
  }

  struct Bind {
    let commonFields: CommonFields

    let maxXmitFrag: UInt16
    let maxRecvFrag: UInt16
    let assocGroup: UInt32
    let context: ContextList
    let contextData: Data

    init(callID: UInt32, context: ContextList) {
      let contextData = context.encoded()
      commonFields = CommonFields(packetType: .bind, callID: callID, data: contextData)

      maxXmitFrag = 0xFFFF
      maxRecvFrag = 0xFFFF
      assocGroup = 0
      self.context = context
      self.contextData = contextData
    }

    func encoded() -> Data {
      var data = Data()
      data += commonFields.encoded()
      data += maxXmitFrag
      data += maxRecvFrag
      data += assocGroup
      data += contextData

      return data
    }
  }

  struct BindAck {
    let commonFields: CommonFields

    let maxRecvFrag: UInt16
    let assocGroup: UInt32
    let secondaryAddress: UInt16
    let context: ContextList
    let contextData: Data

    init(callID: UInt32, context: ContextList) {
      let contextData = context.encoded()
      commonFields = CommonFields(packetType: .bindAck, callID: callID, data: contextData)

      maxRecvFrag = 0xFFFF
      assocGroup = 0
      secondaryAddress = 0
      self.context = context
      self.contextData = contextData
    }

    func encoded() -> Data {
      var data = Data()
      data += commonFields.encoded()
      data += maxRecvFrag
      data += assocGroup
      data += secondaryAddress
      data += contextData

      return data
    }
  }

  struct Request {
    let commonFields: CommonFields

    let allocHint: UInt32
    let contextID: UInt16
    let opnum: Opnum
    let stub: Data

    init(callID: UInt32, opnum: Opnum, stub: Data) {
      commonFields = CommonFields(packetType: .request, callID: callID, data: stub)

      allocHint = 0
      contextID = 0
      self.opnum = opnum
      self.stub = stub
    }

    func encoded() -> Data {
      var data = Data()
      data += commonFields.encoded()
      data += allocHint
      data += contextID
      data += opnum.rawValue
      data += stub

      return data
    }
  }

  struct Response {
    let commonFields: CommonFields
    
    let allocHint: UInt32
    let contextID: UInt16
    let cancelCount: UInt8
    let reserved: UInt8
    let stub: Data

    init(data: Data) {
      let reader = ByteReader(data)

      commonFields = reader.read()
      allocHint = reader.read()
      contextID = reader.read()
      cancelCount = reader.read()
      reserved = reader.read()
      stub = reader.read(count: Int(commonFields.fragLength) - reader.offset)
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
      numberOfItems = UInt8(items.count)
      reserved = 0
      reserved2 = 0
      self.items = items
    }

    init(contextID: UInt16, abstractSyntax: AbstractSyntax, transferSyntaxes: [TransferSyntax]) {
      numberOfItems = 1
      reserved = 0
      reserved2 = 0
      items = [PresentationContext(contextID: contextID, abstractSyntax: abstractSyntax, transferSyntaxes: transferSyntaxes)]
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
      interfaceUUID = Data([0xC8, 0x4F, 0x32, 0x4B, 0x70, 0x16, 0xD3, 0x01, 0x12, 0x78, 0x5A, 0x47, 0xBF, 0x6E, 0xE1, 0x88])
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
      interfaceUUID = Data([0x04, 0x5D, 0x88, 0x8A, 0xEB, 0x1C, 0xC9, 0x11, 0x9F, 0xE8, 0x08, 0x00, 0x2B, 0x10, 0x48, 0x60])
      interfaceVersion = 2
    }

    func encoded() -> Data {
      var data = Data()
      data += interfaceUUID
      data += interfaceVersion

      return data
    }
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
}

extension ByteReader {
  func read() -> DCERPC.CommonFields {
    DCERPC.CommonFields(data: read(count: 16))
  }
}
