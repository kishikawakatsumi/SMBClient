import UIKit
import WebKit
import AVFoundation
import FlyingFox
import FlyingSocks
import SMBClient

class DocumentViewController: UIViewController {
  private let path: String
  private let client: SMBClient
  private let fileReader: FileReader

  private let server: HTTPServer
  private let port: UInt16
  private var task: Task<(), any Error>?
  private let semaphore = Semaphore(value: 1)

  private var webView = WKWebView()
  private var progressBar = UIProgressView(progressViewStyle: .bar)

  init(client: SMBClient, path: String) {
    self.client = client
    self.path = path
    fileReader = client.fileReader(path: path)

    port = UInt16(42000)
    server = HTTPServer(port: port, logger: .disabled)
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  private var observation: NSKeyValueObservation?

  deinit {
    webView.stopLoading()
    observation?.invalidate()
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()

    navigationItem.title = URL(fileURLWithPath: path).lastPathComponent

    webView.navigationDelegate = self
    webView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(webView)
    NSLayoutConstraint.activate([
      webView.topAnchor.constraint(equalTo: view.topAnchor),
      webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      webView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      webView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])

    let progressBar = self.progressBar
    observation = webView.observe(\.estimatedProgress, options: .new) { (_, change) in
      if let progress = change.newValue {
        progressBar.progress = Float(progress)

        if progress == 1.0 {
          progressBar.isHidden = true
        }
      }
    }

    progressBar.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(progressBar)
    NSLayoutConstraint.activate([
      progressBar.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      progressBar.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      progressBar.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])

    let semaphore = self.semaphore
    let fileReader = self.fileReader

    task = Task {
      await server.appendRoute("*") { (request) in
        await semaphore.wait()
        defer { Task { await semaphore.signal() } }

        let bufferedResponse = BufferedResponse(fileReader: fileReader)
        let mimeType = mimeTypeForPath(path: request.path)

        let fileSize = try await fileReader.fileSize
        if let rangeHeader = request.headers[HTTPHeader("Range")] {
          if let range = parseRangeHeader(rangeHeader) {
            let length = {
              let length: UInt64
              let requested = range.upperBound - range.lowerBound + 1
              if fileSize < 512 * 1024 * 1024 {
                length = 1 * 1024 * 1024
              } else if fileSize < 1 * 1024 * 1024 * 1024 {
                length = 2 * 1024 * 1024
              } else if fileSize < 4 * 1024 * 1024 * 1024 {
                length = 3 * 1024 * 1024
              } else if fileSize < 10 * 1024 * 1024 * 1024 {
                length = 4 * 1024 * 1024
              } else {
                length = 8 * 1024 * 1024
              }
              return min(length, requested)
            }()

            let data = try await fileReader.read(offset: range.lowerBound, length: UInt32(truncatingIfNeeded: length))
            let headers = [
              HTTPHeader("Content-Length"): "\(data.count)",
              HTTPHeader("Content-Range"): "bytes \(range.lowerBound)-\(Int(range.lowerBound) + data.count - 1)/\(fileSize)",
              HTTPHeader("Content-Type"): mimeType,
            ]
            return HTTPResponse(
              statusCode: .partialContent,
              headers: headers,
              body: data
            )
          }
        }

        let headers = [
          HTTPHeader("Content-Length"): "\(fileSize)",
          HTTPHeader("Accept-Ranges"): "byte",
          HTTPHeader("Content-Type"): mimeType,
        ]
        return HTTPResponse(
          statusCode: .partialContent,
          headers: headers,
          body: HTTPBodySequence(from: bufferedResponse, count: Int(fileSize))
        )
      }

      try await server.start()
    }

    Task { @MainActor in
      try await server.waitUntilListening()
      webView.load(URLRequest(url: URL(string: "http://localhost:\(port)/\(path)")!))
    }
  }

  override func viewDidDisappear(_ animated: Bool) {
    super.viewDidDisappear(animated)

    Task {
      try await fileReader.close()
    }
    task?.cancel()
  }
}

extension DocumentViewController: WKNavigationDelegate {
  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
    let controller = UIAlertController(title: "", message: error.localizedDescription, preferredStyle: .alert)
    controller.addAction(UIAlertAction(title: NSLocalizedString("Close", comment: ""), style: .default))
    present(controller, animated: true)
  }
}

private struct BufferedResponse: AsyncBufferedSequence {
  typealias Element = UInt8

  let fileReader: FileReader

  init(fileReader: FileReader) {
    self.fileReader = fileReader
  }

  func makeAsyncIterator() -> AsyncIterator {
    AsyncIterator(fileReader: fileReader)
  }

  struct AsyncIterator: AsyncBufferedIteratorProtocol {
    typealias Buffer = Data
    var offset: UInt64 = 0

    let fileReader: FileReader

    init(fileReader: FileReader) {
      self.fileReader = fileReader
    }

    mutating func nextBuffer(suggested count: Int) async throws -> Data? {
      let data = try await fileReader.read(offset: offset)
      offset += UInt64(data.count)
      return data
    }

    mutating func next() async throws -> UInt8? {
      let data = try await fileReader.read(offset: offset, length: 1)
      offset += UInt64(1)
      return data.first
    }
  }
}

private func parseRangeHeader(_ rangeHeader: String) -> Range<UInt64>? {
  guard rangeHeader.hasPrefix("bytes=") else {
    return nil
  }

  let rangeString = rangeHeader.dropFirst("bytes=".count)
  let parts = rangeString.split(separator: "-")
  guard parts.count == 2 else {
    return nil
  }

  guard let start = UInt64(parts[0]) else {
    return nil
  }
  guard let end = UInt64(parts[1]) else {
    return nil
  }
  return start..<end
}

private func mimeTypeForPath(path: String) -> String {
  let url = URL(fileURLWithPath: path)
  let pathExtension = url.pathExtension

  if let type = UTType(filenameExtension: pathExtension) {
    if let mimetype = type.preferredMIMEType {
      return mimetype as String
    }
  }

  return "application/octet-stream"
}
