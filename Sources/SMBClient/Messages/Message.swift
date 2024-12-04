import Foundation

public enum Message {
  public protocol Request {
    associatedtype Response: Message.Response
    func encoded() -> Data
  }

  public protocol Response {
    var header: Header { get }
    init(data: Data)
  }
}
