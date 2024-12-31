import Foundation

public enum Message {
  public protocol Request {
    associatedtype Response: Message.Response

    var header: Header { get }
    
    func encoded() -> Data
    func sign(key: Data) -> Data
  }

  public protocol Response {
    var header: Header { get }
    init(data: Data)
  }

  static func sign(key: Data, packet: Data) -> Data {
    var header = Header(data: packet[..<64])
    let payload = packet[64...]

    header.flags = header.flags.union(.signed)

    let signature = Crypto.hmacSHA256(key: key, data: header.encoded() + payload)[..<16]
    header.signature = signature

    return header.encoded() + payload
  }
}

public extension Message.Request {
  func sign(key: Data) -> Data {
    Message.sign(key: key, packet: encoded())
  }
}
