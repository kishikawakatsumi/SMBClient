import Foundation
import Network

class ServiceDiscovery {
  static let shared = ServiceDiscovery()
  static let serviceDidDiscover = Notification.Name("ServiceDiscoveryServiceDidDiscover")

  private let browser: NWBrowser
  private(set) var services = Set<Service>()

  private init() {
    let params = NWParameters()
    params.includePeerToPeer = true

    let descriptor = NWBrowser.Descriptor.bonjour(type: "_smb._tcp", domain: nil)
    browser = NWBrowser(for: descriptor, using: params)
  }

  func start() {
    browser.browseResultsChangedHandler = { (results, changes) in
      for result in results {
        switch result.endpoint {
        case let .service(name, type, domain, _):
          let service = Service(name: name, type: type, domain: domain)
          self.services.insert(service)

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
