import Foundation

public enum Negotiate {
  public struct Request: Message.Request {
    public typealias Response = Negotiate.Response

    public let header: Header
    public let structureSize: UInt16
    public let dialectCount: UInt16
    public let securityMode: SecurityMode
    public let reserved: UInt16
    public let capabilities: Capabilities
    public let clientGuid: UUID
    // For dialects < 3.1.1 this 8-byte slot carries ClientStartTime (0).
    // For 3.1.1 it carries NegotiateContextOffset(4)+NegotiateContextCount(2)+Reserved2(2).
    public let clientStartTime: UInt64
    public let negotiateContextOffset: UInt32
    public let negotiateContextCount: UInt16
    public let dialects: [Dialects]
    public let padding: Data
    public let negotiateContextList: Data

    public init(
      headerFlags: Header.Flags = [],
      messageId: UInt64,
      securityMode: SecurityMode,
      capabilities: Capabilities = [],
      clientGuid: UUID = UUID(),
      dialects: [Dialects],
      negotiateContexts: [Data] = []
    ) {
      header = Header(
        creditCharge: 1,
        command: .negotiate,
        creditRequest: 0,
        flags: headerFlags,
        messageId: messageId,
        treeId: 0,
        sessionId: 0
      )

      structureSize  = 36
      dialectCount = UInt16(dialects.count)
      self.securityMode = securityMode
      reserved = 0
      self.capabilities = capabilities
      self.clientGuid = clientGuid
      self.dialects = dialects

      // Align the dialect array (2 bytes each) so the negotiate context list
      // starts on an 8-byte boundary relative to the SMB2 header.
      let dialectsEnd = 64 + 36 + dialects.count * 2
      let pad = (8 - (dialectsEnd % 8)) % 8
      padding = Data(count: pad)

      if negotiateContexts.isEmpty {
        clientStartTime = 0
        negotiateContextOffset = 0
        negotiateContextCount = 0
        negotiateContextList = Data()
      } else {
        clientStartTime = 0
        negotiateContextOffset = UInt32(dialectsEnd + pad)
        negotiateContextCount = UInt16(negotiateContexts.count)

        var list = Data()
        for (index, context) in negotiateContexts.enumerated() {
          list += context
          // Contexts (except the last) are padded to an 8-byte boundary.
          if index < negotiateContexts.count - 1 {
            let ctxPad = (8 - (context.count % 8)) % 8
            list += Data(count: ctxPad)
          }
        }
        negotiateContextList = list
      }
    }

    public func encoded() -> Data {
      var data = Data()

      data += header.encoded()

      data += structureSize
      data += dialectCount
      data += securityMode.rawValue
      data += reserved
      data += capabilities.rawValue
      data += Data(from: clientGuid)

      if negotiateContextCount > 0 {
        data += negotiateContextOffset
        data += negotiateContextCount
        data += UInt16(0) // Reserved2
      } else {
        data += clientStartTime
      }

      for dialect in dialects {
        data += dialect.rawValue
      }
      data += padding
      data += negotiateContextList

      return data
    }
  }

  public struct Response: Message.Response {
    public let header: Header
    public let structureSize: UInt16
    public let securityMode: SecurityMode
    public let dialectRevision: UInt16
    public let negotiateContextCount: UInt16
    public let serverGuid: UUID
    public let capabilities: Capabilities
    public let maxTransactSize: UInt32
    public let maxReadSize: UInt32
    public let maxWriteSize: UInt32
    public let systemTime: UInt64
    public let serverStartTime: UInt64
    public let securityBufferOffset: UInt16
    public let securityBufferLength: UInt16
    public let negotiateContextOffset: UInt32
    public let securityBuffer: Data
    // Parsed negotiate contexts keyed by ContextType (3.1.1 only).
    public let negotiateContexts: [UInt16: Data]

    public init(data: Data) {
      let reader = ByteReader(data)

      header = reader.read()

      structureSize = reader.read()
      securityMode = SecurityMode(rawValue: reader.read())
      dialectRevision = reader.read()
      negotiateContextCount = reader.read()
      serverGuid = reader.read()
      capabilities = Capabilities(rawValue: reader.read())
      maxTransactSize = reader.read()
      maxReadSize = reader.read()
      maxWriteSize = reader.read()
      systemTime = reader.read()
      serverStartTime = reader.read()
      securityBufferOffset = reader.read()
      securityBufferLength = reader.read()
      negotiateContextOffset = reader.read()
      securityBuffer = reader.read(from: Int(securityBufferOffset), count: Int(securityBufferLength))

      var contexts = [UInt16: Data]()
      if dialectRevision == Dialects.smb311.rawValue, negotiateContextCount > 0, negotiateContextOffset > 0 {
        var offset = Int(negotiateContextOffset)
        for _ in 0..<negotiateContextCount {
          guard offset + 8 <= data.count else { break }
          reader.seek(to: offset)
          let contextType: UInt16 = reader.read()
          let dataLength: UInt16 = reader.read()
          let _: UInt32 = reader.read() // Reserved
          guard offset + 8 + Int(dataLength) <= data.count else { break }
          let contextData = reader.read(count: Int(dataLength))
          contexts[contextType] = contextData
          // Advance past this context, honoring 8-byte alignment.
          offset += 8 + Int(dataLength)
          offset += (8 - (offset % 8)) % 8
        }
      }
      negotiateContexts = contexts
    }

    /// The cipher selected by the server's ENCRYPTION_CAPABILITIES context
    /// (3.1.1), or nil if none was returned.
    public var selectedCipher: UInt16? {
      guard let data = negotiateContexts[NegotiateContextType.encryptionCapabilities] else { return nil }
      // CipherCount(2) then Ciphers[]; server returns exactly one.
      guard data.count >= 4 else { return nil }
      let reader = ByteReader(data)
      let _: UInt16 = reader.read() // CipherCount
      let cipher: UInt16 = reader.read()
      return cipher
    }
  }

  public struct SecurityMode: OptionSet, Sendable {
    public let rawValue: UInt16

    public init(rawValue: UInt16) {
      self.rawValue = rawValue
    }

    public static let signingEnabled = SecurityMode(rawValue: 0x0001)
    public static let signingRequired = SecurityMode(rawValue: 0x0002)
  }

  public struct Capabilities: OptionSet, Sendable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    public static let dfs = Capabilities(rawValue: 0x00000001)
    public static let leasing = Capabilities(rawValue: 0x00000002)
    public static let largeMtu = Capabilities(rawValue: 0x00000004)
    public static let multiChannel = Capabilities(rawValue: 0x00000008)
    public static let persistentHandles = Capabilities(rawValue: 0x00000010)
    public static let directoryLeasing = Capabilities(rawValue: 0x00000020)
    public static let encryption = Capabilities(rawValue: 0x00000040)
    public static let notifications = Capabilities(rawValue: 0x00000080)
  }

  public enum Dialects: UInt16 {
    case smb202 = 0x0202
    case smb210 = 0x0210
    case smb300 = 0x0300
    case smb302 = 0x0302
    case smb311 = 0x0311
  }
}

// MARK: - Negotiate contexts (SMB 3.1.1)

public enum NegotiateContextType {
  public static let preauthIntegrityCapabilities: UInt16 = 0x0001
  public static let encryptionCapabilities: UInt16 = 0x0002
  public static let compressionCapabilities: UInt16 = 0x0003
  public static let netnameNegotiateContextId: UInt16 = 0x0005
  public static let transportCapabilities: UInt16 = 0x0006
  public static let rdmaTransformCapabilities: UInt16 = 0x0007
  public static let signingCapabilities: UInt16 = 0x0008
}

public enum HashAlgorithm {
  public static let sha512: UInt16 = 0x0001
}

public enum Cipher {
  public static let aes128ccm: UInt16 = 0x0001
  public static let aes128gcm: UInt16 = 0x0002
  public static let aes256ccm: UInt16 = 0x0003
  public static let aes256gcm: UInt16 = 0x0004
}

public enum NegotiateContext {
  /// PREAUTH_INTEGRITY_CAPABILITIES context (SHA-512, caller-supplied salt).
  public static func preauthIntegrity(salt: Data) -> Data {
    var body = Data()
    body += UInt16(1)                 // HashAlgorithmCount
    body += UInt16(salt.count)        // SaltLength
    body += HashAlgorithm.sha512      // HashAlgorithms[0]
    body += salt                      // Salt
    return wrap(type: NegotiateContextType.preauthIntegrityCapabilities, body: body)
  }

  /// ENCRYPTION_CAPABILITIES context listing supported ciphers in preference order.
  public static func encryption(ciphers: [UInt16]) -> Data {
    var body = Data()
    body += UInt16(ciphers.count)     // CipherCount
    for cipher in ciphers {
      body += cipher
    }
    return wrap(type: NegotiateContextType.encryptionCapabilities, body: body)
  }

  private static func wrap(type: UInt16, body: Data) -> Data {
    var data = Data()
    data += type                      // ContextType
    data += UInt16(body.count)        // DataLength
    data += UInt32(0)                 // Reserved
    data += body
    return data
  }
}
