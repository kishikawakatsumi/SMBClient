import Foundation

public enum FileSystemInfoClass: UInt8 {
  case fileFsVolumeInformation = 0x01
  case fileFsLabelInformation = 0x02
  case fileFsSizeInformation = 0x03
  case fileFsDeviceInformation = 0x04
  case fileFsAttributeInformation = 0x05
  case fileFsControlInformation = 0x06
  case fileFsFullSizeInformation = 0x07
  case fileFsObjectIdInformation = 0x08
  case fileFsDriverPathInformation = 0x09
  case fileFsVolumeFlagsInformation = 0x0A
  case fileFsSectorSizeInformation = 0x0B
}
