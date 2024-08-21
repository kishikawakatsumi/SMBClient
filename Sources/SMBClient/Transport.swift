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
    let byte1 = UInt8((length >> 16) & 0x000000FF)
    let byte2 = UInt8((length >> 8) & 0x000000FF)
    let byte3 = UInt8(length & 0x000000FF)
    data.append(byte1)
    data.append(byte2)
    data.append(byte3)
    streamProtocolLength = data

    self.smb2Message = smb2Message
  }

  public init(response: Data) {
    let reader = ByteReader(response)
    zero = 0

    let length = (reader.read() as UInt32).bigEndian

    var data = Data(capacity: 3)
    let byte1 = UInt8((length >> 16) & 0x000000FF)
    let byte2 = UInt8((length >> 8) & 0x000000FF)
    let byte3 = UInt8(length & 0x000000FF)
    data.append(byte1)
    data.append(byte2)
    data.append(byte3)

    streamProtocolLength = data
    protocolLength = length

    smb2Message = Data(reader.remaining())
  }

  public func encoded() -> Data {
    var data = Data()
    data += zero
    data += streamProtocolLength
    data += smb2Message
    return data
  }
}
