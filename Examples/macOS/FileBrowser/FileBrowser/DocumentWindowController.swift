import Cocoa
import WebKit
import AVFoundation
import FlyingFox
import FlyingSocks
import SMBClient

private let storyboardID = "DocumentWindowController"

class DocumentWindowController: NSWindowController, NSWindowDelegate {
  private let path: String
  private let client: SMBClient
  private let fileReader: FileReader

  private let server: HTTPServer
  private let port: UInt16
  private var task: Task<(), any Error>?
  private let semaphore = Semaphore(value: 1)

  static func instantiate(path: String, client: SMBClient) -> Self {
    let storyboard = NSStoryboard(name: storyboardID, bundle: nil)
    return storyboard.instantiateController(identifier: storyboardID) { (coder) in
      Self(coder: coder, path: path, client: client)
    }
  }

  required init?(coder: NSCoder, path: String, client: SMBClient) {
    self.path = path
    self.client = client
    fileReader = client.fileReader(path: path)

    port = UInt16(42000 + NSApp.windows.count)
    server = HTTPServer(port: port, logger: .disabled)

    super.init(coder: coder)
  }

  required init?(coder: NSCoder) {
    return nil
  }

  override func windowDidLoad() {
    super.windowDidLoad()

    window?.appearance = NSAppearance(named: .darkAqua)
    window?.delegate = self

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

      guard let documentViewController = contentViewController as? DocumentViewController else { return }
      documentViewController.load(URLRequest(url: URL(string: "http://localhost:\(port)/\(path)")!))
    }
  }

  func windowWillClose(_ notification: Notification) {
    Task {
      try await fileReader.close()
    }
    task?.cancel()
  }
}

class DocumentViewController: NSViewController {
  @IBOutlet private var webView: WKWebView!
  @IBOutlet private var progressIndicator: NSProgressIndicator!

  private var observation: NSKeyValueObservation?

  deinit {
    webView.stopLoading()
    observation?.invalidate()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    webView.setValue(false, forKey: "drawsBackground")
    webView.navigationDelegate = self

    let progressIndicator = self.progressIndicator!
    observation = webView.observe(\.estimatedProgress, options: .new) { (_, change) in
      if let progress = change.newValue {
        progressIndicator.doubleValue = progress

        if progress == 1.0 {
          progressIndicator.isHidden = true
        }
      }
    }
  }

  func load(_ request: URLRequest) {
    webView.load(request)
  }
}

extension DocumentViewController: WKNavigationDelegate {
  func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
    let script = """
    (function() {
      var images = document.getElementsByTagName('img');
      if (images.length > 0) {
        return {
          width: images[0].naturalWidth,
          height: images[0].naturalHeight
        };
      } else {
        return null;
      }
    })()
    """
    webView.evaluateJavaScript(script) { [weak self] (result, error) in
      guard let window = self?.view.window else {
        return
      }
      guard let dimensions = result as? [String: Any] else {
        return
      }
      guard let width = dimensions["width"] as? Int else {
        return
      }
      guard let height = dimensions["height"] as? Int else {
        return
      }
      guard let currentScreen = NSScreen.screens.first(where: { $0 == window.screen }) else {
        return
      }

      let rect = AVMakeRect(
        aspectRatio: CGSize(width: CGFloat(width), height: CGFloat(height)),
        insideRect: currentScreen.visibleFrame
      )
      let contentSize = NSSize(width: min(rect.width, CGFloat(width)), height: min(rect.height, CGFloat(height)))

      self?.view.window?.setContentSize(contentSize)
      self?.view.window?.center()
    }
  }

  func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
    let script = """
    (function() {
      var videos = document.getElementsByTagName('video');
      if (videos.length > 0) {
        return {
          width: videos[0].videoWidth,
          height: videos[0].videoHeight
        };
      } else {
        return null;
      }
    })()
    """
    webView.evaluateJavaScript(script) { [weak self] (result, error) in
      guard let window = self?.view.window else {
        return
      }
      guard let dimensions = result as? [String: Any] else {
        return
      }
      guard let width = dimensions["width"] as? Int else {
        return
      }
      guard let height = dimensions["height"] as? Int else {
        return
      }
      guard let currentScreen = NSScreen.screens.first(where: { $0 == window.screen }) else {
        return
      }

      let rect = AVMakeRect(
        aspectRatio: CGSize(width: CGFloat(width), height: CGFloat(height)),
        insideRect: currentScreen.visibleFrame
      )
      let contentSize = NSSize(width: min(rect.width, CGFloat(width)), height: min(rect.height, CGFloat(height)))
      if contentSize.width.isNaN || contentSize.height.isNaN {
        return
      }

      self?.view.window?.setContentSize(contentSize)
      self?.view.window?.center()
    }
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
