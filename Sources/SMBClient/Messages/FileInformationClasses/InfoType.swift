import Foundation

public enum InfoType: UInt8 {
  case file = 0x01
  case fileSystem = 0x02
  case security = 0x03
  case quota = 0x04
}
