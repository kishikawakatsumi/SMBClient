import Foundation

class ServerManager {
  static let shared = ServerManager()
  static let serversDidUpdate = Notification.Name("ServerManagerServersDidUpdate")

  private(set) var servers = [Server]()

  private init() {}

  func connectToNewServer() {
    let id = ID(UUID().uuidString)
    let authManager = ServerAuthManager(id: id)

    if let session = authManager.authenticate() {
      let server = Server(
        id: id,
        displayName: session.displayName ?? session.server,
        server: session.server,
        port: session.port
      )
      servers.append(server)

      saveServers()
      NotificationCenter.default.post(name: Self.serversDidUpdate, object: self)
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

  func removeServer(_ server: Server) {
    if let index = servers.firstIndex(where: { $0.id == server.id }) {
      servers.remove(at: index)
      
      saveServers()
      NotificationCenter.default.post(name: Self.serversDidUpdate, object: self)
    }
  }

  func server(for id: ID) -> Server? {
    servers.first { $0.id == id }
  }

  private func saveServers() {
    let encoder = PropertyListEncoder()
    encoder.outputFormat = .binary
    if let data = try? encoder.encode(servers) {
      UserDefaults.standard.setValue(data, forKey: "servers")
    }
  }
}
