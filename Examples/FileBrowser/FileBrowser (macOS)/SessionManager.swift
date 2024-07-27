import Cocoa
import SMBClient

class SessionManager {
  static let shared = SessionManager()
  static let sessionDidDisconnected = Notification.Name("SessionManagerSessionDidDisconnected")

  private var sessions = [ID: Session]()

  private init() {}

  func session(for id: ID) -> Session? {
    sessions[id]
  }

  func sessionExists(for id: ID) -> Bool {
    return session(for: id) != nil
  }

  func login(
    id: ID,
    displayName: String?,
    server: String,
    port: Int? = nil,
    username: String,
    password: String,
    savePassword: Bool
  ) async throws -> Session {
    let client = ClientRegistry.shared.client(id: id, displayName: displayName, server: server, port: port) { (error) in
      ClientRegistry.shared.removeClient(id: id)
      self.sessions[id] = nil

      Task {
        await MainActor.run {
          NotificationCenter.default.post(
            name: Self.sessionDidDisconnected,
            object: self,
            userInfo: [SessionManagerUserInfoKey.error: error]
          )
        }
      }
    }
    try await client.login(username: username, password: password)

    if savePassword {
      let store = CredentialStore.shared
      store.save(server: server, securityDomain: id.rawValue, username: username, password: password)
    }

    let session = Session(id: id, displayName: displayName, server: server, port: port, client: client)
    sessions[id] = session

    return session
  }

  func logoff(id: ID) async {
    do {
      let client = ClientRegistry.shared.client(id: id)
      try await client?.logoff()

      sessions[id] = nil
      ClientRegistry.shared.removeClient(id: id)
    } catch {
      _ = await MainActor.run {
        NSAlert(error: error).runModal()
      }
    }
  }
}

struct SessionManagerUserInfoKey: Hashable, Equatable, RawRepresentable {
  let rawValue: String

  init(rawValue: String) {
    self.rawValue = rawValue
  }
}

extension SessionManagerUserInfoKey {
  static let error = SessionManagerUserInfoKey(rawValue: "error")
}

struct Session {
  let id: ID
  let displayName: String?
  let server: String
  let port: Int?
  let client: SMBClient
}

private class ClientRegistry {
  static let shared = ClientRegistry()
  private var clients = [ID: SMBClient]()

  private init() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationWillTerminate(_:)),
      name: NSApplication.willTerminateNotification,
      object: nil
    )
  }

  func client(id: ID, displayName: String?, server: String, port: Int?, onDisconnected: @escaping (Error) -> Void) -> SMBClient {
    if let client = clients[id] {
      return client
    }

    let client: SMBClient
    if let port {
      client = SMBClient(host: server, port: port)
    } else {
      client = SMBClient(host: server)
    }
    client.onDisconnected = onDisconnected

    clients[id] = client
    return client
  }

  func client(id: ID) -> SMBClient? {
    clients[id]
  }

  func removeClient(id: ID) {
    clients[id] = nil
  }

  @objc
  private func applicationWillTerminate(_ notification: Notification) {
    for client in clients.values {
      Task {
        try await client.logoff()
      }
    }
  }
}

extension CredentialStore {
  @discardableResult
  fileprivate func save(
    server: String,
    securityDomain: String,
    username: String,
    password: String
  ) -> Bool {
    let query: [String: Any] = [
      kSecClass as String: kSecClassInternetPassword,
      kSecAttrServer as String: server,
      kSecAttrSecurityDomain as String: securityDomain,
    ]
    let attributes: [String: Any] = [
      kSecAttrAccount as String: username,
      kSecValueData as String: Data(password.utf8),
      kSecAttrProtocol as String: kSecAttrProtocolSMB,
      kSecAttrLabel as String: "\(server) (\(securityDomain))",
      kSecAttrDescription as String: "Network Password",
    ]

    let status: OSStatus
    if SecItemCopyMatching(query as CFDictionary, nil) == errSecItemNotFound {
      status = SecItemAdd(query.merging(attributes) { (_, new) in new } as CFDictionary, nil)
    } else {
      status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
    }

    return status == errSecSuccess
  }
}
