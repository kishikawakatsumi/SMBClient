import Foundation

public struct FileFsVolumeInformation {
  public let volumeCreationTime: UInt64
  public let volumeSerialNumber: UInt32
  public let volumeLabelLength: UInt32
  public let supportsObjects: Bool
  public let reserved: UInt8
  public let volumeLabel: String

  public init(data: Data) {
    let reader = ByteReader(data)

    volumeCreationTime = reader.read()
    volumeSerialNumber = reader.read()
    volumeLabelLength = reader.read()
    supportsObjects = reader.read() == 1
    reserved = reader.read()
    let volumeLabelData = reader.read(count: Int(volumeLabelLength))
    volumeLabel = String(data: volumeLabelData, encoding: .utf16LittleEndian) ?? volumeLabelData.hex
  }
}
