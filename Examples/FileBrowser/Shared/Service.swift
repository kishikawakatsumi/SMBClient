import Foundation
import Network

struct Service {
  let id: ID
  let name: String
  let type: String
  let domain: String
  let interface: NWInterface?

  init(name: String, type: String, domain: String, interface: NWInterface?) {
    id = ID("smb://\(name)._smb._tcp.local")
    self.name = name
    self.type = type
    self.domain = domain
    self.interface = interface
  }
}

extension Service: Hashable {
  static func == (lhs: Service, rhs: Service) -> Bool {
    return lhs.name == rhs.name && lhs.type == rhs.type && lhs.domain == rhs.domain
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(name)
    hasher.combine(type)
    hasher.combine(domain)
  }
}
