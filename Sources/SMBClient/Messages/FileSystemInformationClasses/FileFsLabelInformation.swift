import Foundation

public struct FileFsLabelInformation {
  public let volumeLabelLength: UInt32
  public let volumeLabel: String

  public init(data: Data) {
    let reader = ByteReader(data)

    volumeLabelLength = reader.read()
    let volumeLabelData = reader.read(count: Int(volumeLabelLength))
    volumeLabel = String(data: volumeLabelData, encoding: .utf16LittleEndian) ?? volumeLabelData.hex
  }
}
