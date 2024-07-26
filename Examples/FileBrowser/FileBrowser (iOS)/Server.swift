import Foundation

struct Server: Codable {
  let id: ID
  let displayName: String
  let server: String
  let port: Int?

  init(id: ID, displayName: String, server: String, port: Int?) {
    self.id = id
    self.displayName = displayName
    self.server = server
    self.port = port
  }
}

extension Server: Hashable {
  static func == (lhs: Server, rhs: Server) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}
