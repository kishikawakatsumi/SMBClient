import Foundation

struct ResolvedService {
  let host: String
  let port: Int
}

enum ServiceResolverError: Error {
  case timeout
  case missingHostName
  case failed([String: NSNumber])
}

final class ServiceResolver: NSObject, @unchecked Sendable {
  private var continuation: CheckedContinuation<ResolvedService, Error>?
  private var netService: NetService?
  private let lock = NSLock()
  private var didFinish = false

  static func resolve(
    name: String,
    type: String,
    domain: String,
    timeout: TimeInterval = 5
  ) async throws -> ResolvedService {
    let resolver = ServiceResolver()
    return try await resolver.start(name: name, type: type, domain: domain, timeout: timeout)
  }

  private func start(
    name: String,
    type: String,
    domain: String,
    timeout: TimeInterval
  ) async throws -> ResolvedService {
    try await withCheckedThrowingContinuation { (cont: CheckedContinuation<ResolvedService, Error>) in
      self.continuation = cont
      DispatchQueue.main.async { [weak self] in
        guard let self else { return }
        let service = NetService(domain: domain, type: type, name: name)
        service.delegate = self
        self.netService = service
        service.schedule(in: .main, forMode: .default)
        service.resolve(withTimeout: timeout)
      }
    }
  }

  private func finish(_ result: Result<ResolvedService, Error>) {
    lock.lock()
    if didFinish { lock.unlock(); return }
    didFinish = true
    lock.unlock()

    netService?.stop()
    netService?.delegate = nil
    netService = nil

    let cont = continuation
    continuation = nil
    switch result {
    case .success(let value): cont?.resume(returning: value)
    case .failure(let error): cont?.resume(throwing: error)
    }
  }
}

extension ServiceResolver: NetServiceDelegate {
  func netServiceDidResolveAddress(_ sender: NetService) {
    var host = sender.hostName ?? ""
    if host.hasSuffix(".") { host.removeLast() }
    guard !host.isEmpty else {
      finish(.failure(ServiceResolverError.missingHostName))
      return
    }
    let port = sender.port > 0 ? sender.port : 445
    finish(.success(ResolvedService(host: host, port: port)))
  }

  func netService(_ sender: NetService, didNotResolve errorDict: [String: NSNumber]) {
    finish(.failure(ServiceResolverError.failed(errorDict)))
  }

  func netServiceDidStop(_ sender: NetService) {
    finish(.failure(ServiceResolverError.timeout))
  }
}
