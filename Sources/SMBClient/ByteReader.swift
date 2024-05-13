import Foundation

class ByteReader {
  private let data: Data
  private(set) var offset = 0

  var availableBytes: Int {
    return data.count - offset
  }

  init(_ data: Data) {
    self.data = data
  }

  func read<T>() -> T {
    let size = MemoryLayout<T>.size
    let value = data[offset..<(offset + size)].to(type: T.self)
    offset += size
    return value
  }

  func read(count: Int) -> Data {
    let value = data[offset..<(offset + count)]
    offset += count
    return Data(value)
  }

  func read(from: Int, count: Int) -> Data {
    seek(to: from)
    return read(count: count)
  }

  func seek(to: Int) {
    offset = to
  }

  func skip(count: Int) {
    offset += count
  }

  func remaining() -> Data {
    return Data(data[offset...])
  }
}

extension ByteReader {
  func read() -> UUID {
    UUID(data: read(count: 16))
  }
}

extension Data {
  init<T>(from value: T) {
    var value = value
    self = Swift.withUnsafeBytes(of: &value) { Data($0) }
  }

  func to<T>(type: T.Type) -> T {
    return self.withUnsafeBytes { $0.load(as: T.self) }
  }
}

extension Data {
  init?(_ hex: String) {
    let len = hex.count / 2
    var data = Data(capacity: len)
    for i in 0..<len {
      let j = hex.index(hex.startIndex, offsetBy: i * 2)
      let k = hex.index(j, offsetBy: 2)
      let bytes = hex[j..<k]
      if var num = UInt8(bytes, radix: 16) {
        data.append(&num, count: 1)
      } else {
        return nil
      }
    }
    self = data
  }

  var hex: String {
    return reduce("") { $0 + String(format: "%02x", $1) }
  }
}
