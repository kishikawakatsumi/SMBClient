import Foundation

extension Read.Request: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Read Request (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Padding: \(String(format: "0x%02x", padding))
      Flags: \(String(format: "0x%02x", flags))
      Read Length: \(length)
      File Offset: \(offset)
      GUID handle File: \(fileId.to(type: UUID.self))
      Min Count: \(minimumCount)
      Channel: \(channel)
      Remaining Bytes: \(remainingBytes)
      Blob Offset: \(readChannelInfoOffset)
      Blob Length: \(readChannelInfoLength)
      Channel Info Blob: \(buffer.hex)
    """
  }
}

extension Read.Response: CustomDebugStringConvertible {
  public var debugDescription: String {
    """
    \(header)
    Read Response (\(String(format: "0x%02x", header.command)))
      StructureSize: \(structureSize)
      Blob Offset: \(dataOffset)
      Reserved: \(String(format: "%02x", reserved))
      Blob Length: \(dataLength)
      Data Rmaining: \(dataRemaining)
      Reserved2: \(String(format: "%08x", reserved2))
      Data: \(buffer)
    """
  }
}

extension Read.Flags: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .readUnbuffered:
      return "Unbuffered"
    case .requestCompressed:
      return "Compressed"
    }
  }
}

extension Read.Channel: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .none:
      return "None"
    case .rdmaV1:
      return "RDMA V1"
    case .rdmaV1Invalidate:
      return "RDMA V1_INVALIDATE"
    }
  }
}
