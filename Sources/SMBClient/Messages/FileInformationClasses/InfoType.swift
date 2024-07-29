import Foundation

public enum InfoType: UInt8 {
  case file = 0x01
  case fileSystem = 0x02
  case security = 0x03
  case quota = 0x04
}

extension InfoType: CustomDebugStringConvertible {
  public var debugDescription: String {
    switch self {
    case .file:
      return "FILE_INFO (\(String(format: "0x%02x", rawValue)))"
    case .fileSystem:
      return "FS_INFO (\(String(format: "0x%02x", rawValue)))"
    case .security:
      return "SEC_INFO (\(String(format: "0x%02x", rawValue)))"
    case .quota:
      return "QUOTA_INFO (\(String(format: "0x%02x", rawValue)))"
    }
  }

  static public func debugDescription(rawValue: UInt8) -> String {
    if let infoType = InfoType(rawValue: rawValue) {
      return infoType.debugDescription
    } else {
      return String(format: "0x%02x", rawValue)
    }
  }
}
