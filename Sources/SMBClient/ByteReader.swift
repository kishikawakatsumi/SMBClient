import Foundation

class ByteReader {
  private let data: Data
  private(set) var offset: Data.Index

  var availableBytes: Int {
    return data.count - offset
  }

  init(_ data: Data) {
    self.data = data
    offset = data.startIndex
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
    seek(to: data.startIndex + from)
    return read(count: count)
  }

  func seek(to: Int) {
    offset = data.startIndex + to
  }

  func remaining() -> Data {
    return Data(data[offset...])
  }
}

extension ByteReader {
  func read() -> Bool {
    let value: UInt8 = read()
    return value == 1
  }

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
