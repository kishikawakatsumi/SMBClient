import Foundation

public struct FileFsSizeInformation {
  public let totalAllocationUnits: UInt64
  public let availableAllocationUnits: UInt64
  public let sectorsPerAllocationUnit: UInt32
  public let bytesPerSector: UInt32

  public init(data: Data) {
    let reader = ByteReader(data)

    totalAllocationUnits = reader.read()
    availableAllocationUnits = reader.read()
    sectorsPerAllocationUnit = reader.read()
    bytesPerSector = reader.read()
  }
}
