import Foundation

class DataRepository {
  static let shared = DataRepository()
  var data = [String: [Node]]()

  private init() {}

  func set(_ path: String, nodes: [Node]) {
    data[path] = nodes.map { $0.detach() }
  }

  func nodes(_ path: String) -> [Node]? {
    data[path]
  }
}
