import Foundation

class ServerManager {
  static let shared = ServerManager()
  static let serversDidUpdate = Notification.Name("ServerManagerServersDidUpdate")

  private(set) var servers = [Server]()

  private init() {}

  func addServer(id: ID, displayName: String, server: String, port: Int?) {
    let server = Server(
      id: id,
      displayName: displayName.isEmpty ? server : displayName,
      server: server,
      port: port
    )

    guard !servers.contains(server) else { return }
    servers.append(server)

    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    if let data = try? encoder.encode(servers) {
      UserDefaults.standard.setValue(data, forKey: "servers")
    }
  }

  func removeServer(_ server: Server) {
    guard let index = servers.firstIndex(of: server) else { return }
    servers.remove(at: index)

    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    if let data = try? encoder.encode(servers) {
      UserDefaults.standard.setValue(data, forKey: "servers")
    }
  }

  func restoreSavedServers() {
    guard let data = UserDefaults.standard.data(forKey: "servers") else {
      return
    }

    let decoder = PropertyListDecoder()
    guard let servers = try? decoder.decode([Server].self, from: data) else {
      return
    }
    guard !servers.isEmpty else { return }

    self.servers = servers
    NotificationCenter.default.post(name: Self.serversDidUpdate, object: self)
  }

  func server(for id: ID) -> Server? {
    servers.first { $0.id == id }
  }
}
