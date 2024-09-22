import Foundation
import AVFoundation
import SMBClient

private let readSize = UInt32(1024 * 1024 * 4)

class SMBAVAsset: AVURLAsset {
  private let resourceLoaderDelegate: AssetResourceLoaderDelegate

  init(client: SMBClient, path: String) {
    let url = URL(string: "smb:///\(path)")!

    self.resourceLoaderDelegate = AssetResourceLoaderDelegate(
      client: client,
      path: path,
      contentType: url.pathExtension
    )

    super.init(url: url, options: nil)

    resourceLoader.setDelegate(resourceLoaderDelegate, queue: .global())
  }

  func close() {
    resourceLoaderDelegate.close()
  }
}

private class AssetResourceLoaderDelegate: NSObject, AVAssetResourceLoaderDelegate {
  private let client: SMBClient
  private let fileReader: FileReader
  private let path: String
  private let contentType: String?

  private let queue = TaskQueue()

  init(client: SMBClient, path: String, contentType: String?) {
    self.client = client
    fileReader = client.fileReader(path: path)
    self.path = path
    self.contentType = contentType
  }

  func close() {
    Task {
      try await fileReader.close()
    }
  }

  func resourceLoader(
    _ resourceLoader: AVAssetResourceLoader,
    shouldWaitForLoadingOfRequestedResource loadingRequest: AVAssetResourceLoadingRequest
  ) -> Bool {
    if let contentRequest = loadingRequest.contentInformationRequest {
      queue.dispatch { [weak self] in
        guard let self else { return }

        contentRequest.contentType = self.contentType
        contentRequest.contentLength = Int64(truncatingIfNeeded: try await fileReader.fileSize)
        contentRequest.isByteRangeAccessSupported = true
        loadingRequest.finishLoading()
      }
      return true
    }

    if let dataRequest = loadingRequest.dataRequest {
      if dataRequest.requestsAllDataToEndOfResource {
        queue.dispatch { [weak self] in
          guard let self else { return }

          let data = try await fileReader.read(
            offset: UInt64(dataRequest.requestedOffset),
            length: readSize
          )

          dataRequest.respond(with: data)
          loadingRequest.finishLoading()
        }
      } else {
        queue.dispatch { [weak self] in
          guard let self else { return }

          let data = try await fileReader.read(
            offset: UInt64(dataRequest.requestedOffset),
            length: readSize
          )

          dataRequest.respond(with: data)
          loadingRequest.finishLoading()
        }
      }
    }

    return true
  }
}

private class TaskQueue {
  private let queue = Queue()

  func dispatch(_ block: @escaping () async throws -> Void) {
    Task {
      await queue.append(block)
    }
  }
}

private actor Queue {
  private var blocks : [() async throws -> Void] = []
  private var currentTask: Task<Void, Swift.Error>? = nil

  func append(_ block: @escaping () async throws -> Void) {
    blocks.append(block)
    next()
  }

  func next() {
    if let _ = currentTask {
      return
    }
    guard !blocks.isEmpty else {
      return
    }
    let block = blocks.removeFirst()
    currentTask = Task {
      try await block()
      currentTask = nil
      next()
    }
  }
}
