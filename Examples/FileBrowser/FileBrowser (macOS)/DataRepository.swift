import Foundation

class DataRepository {
  static let shared = DataRepository()
  var data = [String: [Node]]()

  private init() {}

  func set<Item: Node>(_ path: String, nodes: [Item]) {
    data[path] = nodes.map { $0.detach() }
  }

  func nodes<Item: Node>(_ path: String) -> [Item]? {
    data[path] as? [Item]
  }
}
