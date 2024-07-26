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
}

struct Credential {
  let server: String
  let username: String
  let password: String
}
