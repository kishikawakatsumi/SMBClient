import Foundation

class CredentialStore {
  static let shared = CredentialStore()

  private init() {}

  func load(server: String, securityDomain: String? = nil) -> Credential? {
    var query: [String: Any] = [
      kSecClass as String: kSecClassInternetPassword,
      kSecAttrServer as String: server,
      kSecReturnAttributes as String: true,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    if let securityDomain {
      query[kSecAttrSecurityDomain as String] = securityDomain
    }

    var result: CFTypeRef?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status != errSecItemNotFound else { return nil }
    guard status == errSecSuccess else { return nil }
    guard let result = result as? NSDictionary else { return nil }
    guard let username = result[kSecAttrAccount] as? String else { return nil }
    guard let passwordData = result[kSecValueData] as? Data else { return nil }

    let password = String(decoding: passwordData, as: UTF8.self)
    return Credential(server: server, username: username, password: password)
  }

  @discardableResult
  func save(
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

struct Credential {
  let server: String
  let username: String
  let password: String
}
