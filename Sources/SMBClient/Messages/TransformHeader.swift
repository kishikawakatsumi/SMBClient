import Foundation

/// SMB2 TRANSFORM_HEADER (MS-SMB2 2.2.41), used to wrap encrypted messages.
/// Fixed size 52 bytes; the plaintext SMB2 message follows as ciphertext.
public struct TransformHeader {
  public static let protocolId: UInt32 = 0x424D53FD // "\xFDSMB"
  public static let size = 52

  public var signature: Data       // 16-byte AEAD tag
  public var nonce: Data           // 16-byte nonce field (GCM uses first 12)
  public var originalMessageSize: UInt32
  public var flags: UInt16         // 0x0001 = encrypted (3.1.1)
  public var sessionId: UInt64

  public init(signature: Data, nonce: Data, originalMessageSize: UInt32, flags: UInt16 = 0x0001, sessionId: UInt64) {
    self.signature = signature
    self.nonce = nonce
    self.originalMessageSize = originalMessageSize
    self.flags = flags
    self.sessionId = sessionId
  }

  public init(data: Data) {
    let reader = ByteReader(data)
    let _: UInt32 = reader.read()          // ProtocolId
    signature = reader.read(count: 16)
    nonce = reader.read(count: 16)
    originalMessageSize = reader.read()
    let _: UInt16 = reader.read()          // Reserved
    flags = reader.read()
    sessionId = reader.read()
  }

  /// Encode with the given signature. When `includeSignature` is false the
  /// 16-byte signature field is zeroed (not used by SMB, but keeps callers
  /// explicit).
  public func encoded() -> Data {
    var data = Data()
    data += TransformHeader.protocolId
    data += signature.count == 16 ? signature : (signature + Data(count: 16 - signature.count))
    data += nonce.count == 16 ? nonce : (nonce + Data(count: 16 - nonce.count))
    data += originalMessageSize
    data += UInt16(0) // Reserved
    data += flags
    data += sessionId
    return data
  }

  /// The associated authenticated data for AEAD: the transform header bytes
  /// following the 16-byte signature field (Nonce..SessionId), i.e. offset
  /// 20..<52 of the encoded header.
  public var associatedData: Data {
    Data(encoded()[20..<TransformHeader.size])
  }
}
