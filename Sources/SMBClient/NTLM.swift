import Foundation
import CommonCrypto

public enum NTLM {
  public struct NegotiateMessage {
    public let signature: UInt64
    public let messageType: UInt32
    public let negotiateFlags: NegotiateFlags
    public let domainNameFields: Fields
    public let workstationNameFields: Fields
    public let version: UInt64

    public init(
      negotiateFlags: NegotiateFlags = [
        .negotiate56,
        .negotiateKeyExchange,
        .negotiate128,
        .negotiateVersion,
        .negotiateTargetInfo,
        .negotiateExtendedSecurity,
        .negotiateAlwaysSign,
        .negotiateNetware,
        .negotiateSeal,
        .negotiateSign,
        .requestTarget,
        .unicode,
      ],
      domainName: String? = nil,
      workstationName: String? = nil
    ) {
      signature = 0x005053534D4C544E
      messageType = 0x00000001
      self.negotiateFlags = negotiateFlags

      let domainNameFields = Fields(
        value: domainName,
        offset: 8 + // Signature
                4 + // MessageType
                4 + // NegotiateFlags
                8 + // DomainNameFields
                8 + // WorkstationFields
                8   // Version
      )
      self.domainNameFields = domainNameFields

      let workstationNameFields = Fields(
        value: workstationName,
        offset: domainNameFields.nextOffset
      )
      self.workstationNameFields = workstationNameFields

      version = 0x0000000000000000
    }

    public func encoded() -> Data {
      var data = Data()

      data += signature
      data += messageType
      data += negotiateFlags.rawValue

      data += domainNameFields.len
      data += domainNameFields.maxLen
      data += domainNameFields.bufferOffset

      data += workstationNameFields.len
      data += workstationNameFields.maxLen
      data += workstationNameFields.bufferOffset

      data += version
      data += domainNameFields.value + workstationNameFields.value

      return data
    }
  }

  public struct ChallengeMessage {
    public let signature: UInt64
    public let messageType: UInt32
    public let targetNameLen: UInt16
    public let targetNameMaxLen: UInt16
    public let targetNameBufferOffset: UInt32
    public let negotiateFlags: NegotiateFlags
    public let serverChallenge: UInt64
    public let reserved: UInt64
    public let targetInfoLen: UInt16
    public let targetInfoMaxLen: UInt16
    public let targetInfoBufferOffset: UInt32
    public let version: UInt64
    public let targetName: Data
    public let targetInfo: Data

    private let buffer: Data

    public init(data: Data) {
      let reader = ByteReader(data)

      signature = reader.read()
      messageType = reader.read()
      targetNameLen = reader.read()
      targetNameMaxLen = reader.read()
      targetNameBufferOffset = reader.read()
      negotiateFlags = NegotiateFlags(rawValue: reader.read())
      serverChallenge = reader.read()
      reserved = reader.read()
      targetInfoLen = reader.read()
      targetInfoMaxLen = reader.read()
      targetInfoBufferOffset = reader.read()
      version = reader.read()
      targetName = reader.read(from: Int(targetNameBufferOffset), count: Int(targetNameLen))
      targetInfo = reader.read(from: Int(targetInfoBufferOffset), count: Int(targetInfoLen))

      buffer = data
    }

    func ntowfv2(
      username: String,
      password: String,
      domain: String
    ) -> Data {
      let passwordData = password.data(using: .utf16LittleEndian) ?? Data()
      let usernameData = (username.uppercased() + domain).data(using: .utf16LittleEndian) ?? Data()

      let responseKeyNT = Crypto.hmacMD5(key: Crypto.md4(passwordData), data: usernameData)
      return responseKeyNT
    }

    func authenticateMessage(
      username: String? = nil,
      password: String? = nil,
      domain: String? = nil,
      workstation: String? = nil,
      negotiateMessage: Data,
      signingKey: Data
    ) -> AuthenticateMessage {
      let responseKeyNT = ntowfv2(
        username: username ?? "",
        password: password ?? "",
        domain: domain ?? ""
      )

      let clientChallenge = Crypto.randomBytes(count: 8)

      let ntlmv2ClientChallenge = NTLMv2ClientChallenge(
        challengeFromClient: clientChallenge,
        avPairs: targetInfo
      )

      let temp = ntlmv2ClientChallenge.encoded()

      let ntProofStr = Crypto.hmacMD5(key: responseKeyNT, data: Data() + serverChallenge + temp)
      let sessionBaseKey = Crypto.hmacMD5(key: responseKeyNT, data: ntProofStr)

      let encryptedRandomSessionKey = Crypto.rc4(key: sessionBaseKey, data: signingKey)

      let ntChallengeResponse = ntProofStr + temp

      var authenticateMessage = NTLM.AuthenticateMessage(
        ntChallengeResponse: ntChallengeResponse,
        domainName: domain,
        userName: username,
        workstationName: workstation,
        encryptedRandomSessionKey: encryptedRandomSessionKey
      )
      let mic = Crypto.hmacMD5(
        key: signingKey,
        data: negotiateMessage + buffer + authenticateMessage.encoded()
      )

      authenticateMessage.mic = mic

      return authenticateMessage
    }
  }

  public struct AuthenticateMessage {
    public let signature: UInt64
    public let messageType: UInt32
    public let lmChallengeResponseFields: Fields
    public let ntChallengeResponseFields: Fields
    public let domainNameFields: Fields
    public let userNameFields: Fields
    public let workstationNameFields: Fields
    public let encryptedRandomSessionKeyFields: Fields
    public let negotiateFlags: NegotiateFlags
    public let version: UInt64
    public internal(set) var mic: Data

    public init(
      ntChallengeResponse: Data,
      domainName: String? = nil,
      userName: String? = nil,
      workstationName: String? = nil,
      encryptedRandomSessionKey: Data? = nil,
      mic: Data = Data()
    ) {
      signature = 0x005053534D4C544E
      messageType = 0x00000003

      let lmChallengeResponseFields = Fields(
        value: Data(count: 24),
        offset: 8 + // Signature
                4 + // MessageType
                8 + // LmChallengeResponseFields
                8 + // NtChallengeResponseFields
                8 + // DomainNameFields
                8 + // UserNameFields
                8 + // WorkstationFields
                8 + // EncryptedRandomSessionKeyFields
                4 + // NegotiateFlags
                8 + // Version
                16  // MIC
      )
      self.lmChallengeResponseFields = lmChallengeResponseFields

      let ntChallengeResponseFields = Fields(
        value: ntChallengeResponse,
        offset: lmChallengeResponseFields.nextOffset
      )
      self.ntChallengeResponseFields = ntChallengeResponseFields

      let domainNameFields = Fields(
        value: domainName?.data(using: .utf16LittleEndian),
        offset: ntChallengeResponseFields.nextOffset
      )
      self.domainNameFields = domainNameFields

      let userNameFields = Fields(
        value: userName?.data(using: .utf16LittleEndian),
        offset: domainNameFields.nextOffset
      )
      self.userNameFields = userNameFields

      let workstationNameFields = Fields(
        value: workstationName?.data(using: .utf16LittleEndian),
        offset: userNameFields.nextOffset
      )
      self.workstationNameFields = workstationNameFields

      let encryptedRandomSessionKeyFields = Fields(
        value: encryptedRandomSessionKey,
        offset: workstationNameFields.nextOffset
      )
      self.encryptedRandomSessionKeyFields = encryptedRandomSessionKeyFields

      negotiateFlags = [
        .negotiateKeyExchange,
        .negotiate128,
        .negotiateVersion,
        .negotiateTargetInfo,
        .negotiateExtendedSecurity,
        .negotiateAlwaysSign,
        .negotiateNetware,
        .negotiateSeal,
        .negotiateSign,
        .requestTarget,
        .unicode,
      ]

      version = 0x0F00000000020A00
      self.mic = mic.isEmpty ? Data(count: 16) : mic
    }
    
    public func encoded() -> Data {
      var data = Data()

      data += signature
      data += messageType
      data += lmChallengeResponseFields.encoded()
      data += ntChallengeResponseFields.encoded()
      data += domainNameFields.encoded()
      data += userNameFields.encoded()
      data += workstationNameFields.encoded()
      data += encryptedRandomSessionKeyFields.encoded()
      data += negotiateFlags.rawValue
      data += version
      data += mic

      data += lmChallengeResponseFields.value
      data += ntChallengeResponseFields.value

      data += domainNameFields.value
      data += userNameFields.value
      data += workstationNameFields.value
      data += encryptedRandomSessionKeyFields.value

      return data
    }
  }

  public struct NegotiateFlags: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    public static let negotiate56 = NegotiateFlags(rawValue: 0x80000000)
    public static let negotiateKeyExchange = NegotiateFlags(rawValue: 0x40000000)
    public static let negotiate128 = NegotiateFlags(rawValue: 0x20000000)
    public static let negotiateVersion = NegotiateFlags(rawValue: 0x02000000)
    public static let negotiateTargetInfo = NegotiateFlags(rawValue: 0x00800000)
    public static let requestNonNTSessionKey = NegotiateFlags(rawValue: 0x00400000)
    public static let negotiateIdentify = NegotiateFlags(rawValue: 0x00100000)
    public static let negotiateExtendedSecurity = NegotiateFlags(rawValue: 0x00080000)
    public static let negotiateTargetTypeServer = NegotiateFlags(rawValue: 0x00020000)
    public static let negotiateTargetTypeDomain = NegotiateFlags(rawValue: 0x00010000)
    public static let negotiateAlwaysSign = NegotiateFlags(rawValue: 0x00008000)
    public static let negotiateOemWorkstationSupplied = NegotiateFlags(rawValue: 0x00002000)
    public static let negotiateOemDomainSupplied = NegotiateFlags(rawValue: 0x00001000)
    public static let negotiateAnonymous = NegotiateFlags(rawValue: 0x00000800)
    public static let negotiateNetware = NegotiateFlags(rawValue: 0x00000200)
    public static let negotiateLanManagerKey = NegotiateFlags(rawValue: 0x00000080)
    public static let negotiateDatagramStyle = NegotiateFlags(rawValue: 0x00000040)
    public static let negotiateSeal = NegotiateFlags(rawValue: 0x00000020)
    public static let negotiateSign = NegotiateFlags(rawValue: 0x00000010)
    public static let requestTarget = NegotiateFlags(rawValue: 0x00000004)
    public static let oem = NegotiateFlags(rawValue: 0x00000002)
    public static let unicode = NegotiateFlags(rawValue: 0x00000001)
  }

  public struct Fields {
    public let len: UInt16
    public let maxLen: UInt16
    public let bufferOffset: UInt32
    public let value: Data

    let nextOffset: UInt32

    public init(value: Data?, offset: UInt32) {
      let value = value ?? Data()

      len = UInt16(value.count)
      maxLen = len
      bufferOffset = offset
      self.value = value

      nextOffset = offset + UInt32(len)
    }

    public init(value: String?, offset: UInt32) {
      let value = value ?? ""
      if let data = value.data(using: .ascii), !data.isEmpty {
        len = UInt16(truncatingIfNeeded: data.count)
        maxLen = len
        bufferOffset = offset
        self.value = data + Data(count: 1)

        nextOffset = offset + UInt32(len) + 1
      } else {
        len = 0
        maxLen = len
        bufferOffset = offset
        self.value = Data()

        nextOffset = offset
      }
    }

    public func encoded() -> Data {
      var data = Data()
      data += len
      data += maxLen
      data += bufferOffset
      return data
    }
  }
}

struct NTLMv2ClientChallenge {
  let respType: UInt8
  let hiRespType: UInt8
  let reserved1: UInt16
  let reserved2: UInt32
  let timeStamp: UInt64
  let challengeFromClient: Data
  let reserved3: UInt32
  let avPairs: Data

  init(challengeFromClient: Data, avPairs: Data) {
    respType = 0x01
    hiRespType = 0x01
    reserved1 = 0x0000
    reserved2 = 0x00000000
    
    let now = Date()
    let fileTime = FileTime(now)

    self.timeStamp = fileTime.raw
    self.challengeFromClient = challengeFromClient
    reserved3 = 0x00000000
    self.avPairs = avPairs
  }

  func encoded() -> Data {
    var data = Data()
    data += respType
    data += hiRespType
    data += reserved1
    data += reserved2
    data += timeStamp
    data += challengeFromClient
    data += reserved3
    data += avPairs
    data += Data(count: 8)
    return data
  }
}

struct AVPair {
  let avId: AVId
  let avLen: UInt16
  let avValue: Data

  enum AVId: UInt16 {
    case eol = 0x0000
    case nbComputerName = 0x0001
    case nbDomainName = 0x0002
    case dnsComputerName = 0x0003
    case dnsDomainName = 0x0004
    case dnsTreeName = 0x0005
    case flags = 0x0006
    case timestamp = 0x0007
    case singleHost = 0x0008
    case targetName = 0x0009
    case channelBindings = 0x000a
  }

  init(avId: AVId, avValue: Data) {
    self.avId = avId
    avLen = UInt16(avValue.count)
    self.avValue = avValue
  }

  init(data: Data) {
    let reader = ByteReader(data)
    avId = AVId(rawValue: reader.read())!
    avLen = reader.read()
    avValue = reader.read(count: Int(avLen))
  }
  
  func encoded() -> Data {
    var data = Data()
    data += avId.rawValue
    data += avLen
    data += avValue
    return data
  }
}
