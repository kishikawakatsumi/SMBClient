import Foundation

public struct ErrorResponse: Error {
  public let header: Header
  public let structureSize: UInt16
  public let errorContextCount: UInt8
  public let reserved: UInt8

  public init(data: Data) {
    let reader = ByteReader(data)

    header = reader.read()
    structureSize = reader.read()
    errorContextCount = reader.read()
    reserved = reader.read()
  }
}

extension ErrorResponse: CustomStringConvertible {
  public var description: String {
    return NTStatus(header.status).description
  }
}

extension ErrorResponse: LocalizedError {
  public var errorDescription: String? {
    return description
  }
}
