import Foundation

public struct DirectTCPPacket {
  public let zero: UInt8
  private let streamProtocolLength: Data
  public let protocolLength: UInt32
  public let smb2Message: Data

  public init(smb2Message: Data) {
    zero = 0x00

    let length = UInt32(truncatingIfNeeded: smb2Message.count)
    protocolLength = length

    var data = Data(capacity: 3)
    let byte1 = UInt8((length >> 16) & 0xFF)
    let byte2 = UInt8((length >> 8) & 0xFF)
    let byte3 = UInt8(length & 0xFF)
    data.append(byte1)
    data.append(byte2)
    data.append(byte3)
    streamProtocolLength = data

    self.smb2Message = smb2Message
  }

  public init(response: Data) {
    let byteReader = ByteReader(response)
    zero = 0

    let length: UInt32 = byteReader.read()
    
    var data = Data(capacity: 3)
    let byte1 = UInt8((length >> 16) & 0xFF)
    let byte2 = UInt8((length >> 8) & 0xFF)
    let byte3 = UInt8(length & 0xFF)
    data.append(byte1)
    data.append(byte2)
    data.append(byte3)

    streamProtocolLength = data
    protocolLength = length.bigEndian

    smb2Message = Data(byteReader.remaining())
  }

  public func encoded() -> Data {
    var data = Data()
    data += zero
    data += streamProtocolLength
    data += smb2Message
    return data
  }
}
