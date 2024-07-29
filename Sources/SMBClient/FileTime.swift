import Foundation

public struct FileTime {
  let raw: UInt64

  init(_ raw: UInt64) {
    self.raw = raw
  }

  init(_ date: Date) {
    let epoch = Date(timeIntervalSince1970: -11644473600)
    let timeInterval = date.timeIntervalSince(epoch)
    raw = UInt64(timeInterval * 10_000_000)
  }

  public var date: Date {
    let timeInterval = Double(raw) / 10_000_000
    return Date(timeIntervalSince1970: timeInterval - 11644473600)
  }
}

extension FileTime: CustomDebugStringConvertible {
  public var debugDescription: String {
    if raw == 0 {
      return "No time specified \(raw)"
    } else {
      return date.description
    }
  }
}
