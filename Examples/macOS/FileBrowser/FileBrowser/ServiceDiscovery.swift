import Foundation
import Network

class ServiceDiscovery {
  static let shared = ServiceDiscovery()
  static let serviceDidDiscover = Notification.Name("ServiceDiscoveryServiceDidDiscover")

  private let browser: NWBrowser
  private(set) var services: [Service]

  private init() {
    let params = NWParameters()
    params.includePeerToPeer = true

    let descriptor = NWBrowser.Descriptor.bonjour(type: "_smb._tcp", domain: nil)
    browser = NWBrowser(for: descriptor, using: params)

    services = [Service]()
  }

  func start() {
    browser.browseResultsChangedHandler = { (results, changes) in
      for result in results {
        switch result.endpoint {
        case .service(name: let name, type: let type, domain: let domain, interface: let interface):
          let service = Service(name: name, type: type, domain: domain, interface: interface)
          guard !self.services.contains(service) else { return }
          
          self.services.append(service)

          NotificationCenter.default.post(name: Self.serviceDidDiscover, object: self)
        case .hostPort, .unix, .url, .opaque:
          break
        @unknown default:
          break
        }
      }
    }

    browser.start(queue: .main)
  }
}
