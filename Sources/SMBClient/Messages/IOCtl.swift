import Foundation

public enum IOCtl {
  public struct Request: Message.Request {
    public typealias Response = IOCtl.Response

    public let header: Header
    public let structureSize: UInt16
    public let reserved: UInt16
    public let ctlCode: UInt32
    public let fileId: Data
    public let inputOffset: UInt32
    public let inputCount: UInt32
    public let maxInputResponse: UInt32
    public let outputOffset: UInt32
    public let outputCount: UInt32
    public let maxOutputResponse: UInt32
    public let flags: Flags
    public let reserved2: UInt32
    public let buffer: Data

    public init(
      headerFlags: Header.Flags = [],
      creditCharge: UInt16,
      messageId: UInt64,
      treeId: UInt32,
      sessionId: UInt64,
      ctlCode: CtlCode,
      fileId: Data,
      input: Data,
      output: Data
    ) {
      header = Header(
        creditCharge: creditCharge,
        command: .ioctl,
        creditRequest: 256,
        flags: headerFlags,
        messageId: messageId,
        treeId: treeId,
        sessionId: sessionId
      )

      structureSize = 57
      reserved = 0
      self.ctlCode = ctlCode.rawValue
      self.fileId = fileId
      inputOffset = 120
      inputCount = UInt32(truncatingIfNeeded: input.count)
      maxInputResponse = 0
      outputOffset = 0
      outputCount = 0
      maxOutputResponse = 65536
      flags = [.isFsctl]
      reserved2 = 0
      buffer = input + output
    }

    public func encoded() -> Data {
      var data = Data()

      data += header.encoded()
      data += structureSize
      data += reserved
      data += ctlCode
      data += fileId
      data += inputOffset
      data += inputCount
      data += maxInputResponse
      data += outputOffset
      data += outputCount
      data += maxOutputResponse
      data += flags.rawValue
      data += reserved2
      data += buffer

      return data
    }
  }

  public struct Response: Message.Response {
    public let header: Header
    public let structureSize: UInt16
    public let reserved: UInt16
    public let ctlCode: UInt32
    public let fileId: Data
    public let inputOffset: UInt32
    public let inputCount: UInt32
    public let outputOffset: UInt32
    public let outputCount: UInt32
    public let flags: Flags
    public let reserved2: UInt32
    public let buffer: Data

    public init(data: Data) {
      let reader = ByteReader(data)

      header = reader.read()

      structureSize = reader.read()
      reserved = reader.read()
      ctlCode = reader.read()
      fileId = reader.read(count: 16)
      inputOffset = reader.read()
      inputCount = reader.read()
      outputOffset = reader.read()
      outputCount = reader.read()
      flags = Flags(rawValue: reader.read())
      reserved2 = reader.read()
      buffer = reader.read(count: Int(outputCount))
    }
  }

  public enum CtlCode: UInt32 {
    case dfsGetReferrals = 0x00060194
    case pipePeek = 0x0011400C
    case pipeWait = 0x00110018
    case pipeTransceive = 0x0011C017
    case srvCopyChunk = 0x001440F2
    case srvEnumerateSnapshots = 0x00144064
    case srvRequestResumeKey = 0x00140078
    case srvReadHash = 0x001441BB
    case srvCopyChunkWrite = 0x001480F2
    case lmrRequestResiliency = 0x001401D4
    case queryNetworkInterfaceInfo = 0x001401FC
    case setReleasePoint = 0x000900A4
    case dfsGetReferralsEx = 0x000601B0
    case fileLevelTrim = 0x00098208
    case validateNegotiateInfo = 0x00140204
  }

  public struct Flags: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    public static let isIoctl = Flags([]) // 0x00000000
    public static let isFsctl = Flags(rawValue: 0x00000001)
  }
}
