import Foundation
import AVFoundation
import SMBClient

class SMBAVAsset: AVURLAsset {
  private let resourceLoaderDelegate: AssetResourceLoaderDelegate

  init(client: SMBClient, path: String) {
    let url = URL(string: "smb://\(path)")!

    self.resourceLoaderDelegate = AssetResourceLoaderDelegate(
      client: client,
      path: path,
      contentType: url.pathExtension
    )

    super.init(url: url, options: nil)

    resourceLoader.setDelegate(resourceLoaderDelegate, queue: .global())
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
      }
    }

    if let dataRequest = loadingRequest.dataRequest {
      if dataRequest.requestsAllDataToEndOfResource {
        queue.dispatch { [weak self] in
          guard let self else { return }

          let fileSize = try await fileReader.fileSize
          let length = chunkSize(fileSize, dataRequest.requestedLength)

          let data = try await fileReader.read(
            offset: UInt64(dataRequest.requestedOffset),
            length: UInt32(truncatingIfNeeded: length)
          )

          dataRequest.respond(with: data)
          loadingRequest.finishLoading()
        }
      } else {
        queue.dispatch { [weak self] in
          guard let self else { return }

          let fileSize = try await fileReader.fileSize
          let length = chunkSize(fileSize, dataRequest.requestedLength)

          let data = try await fileReader.read(
            offset: UInt64(dataRequest.requestedOffset),
            length: UInt32(truncatingIfNeeded: length)
          )

          dataRequest.respond(with: data)
          loadingRequest.finishLoading()
        }
      }
    }

    return true
  }
}

private func chunkSize(_ fileSize: UInt64, _ requestedLength: Int) -> UInt64 {
  let length: UInt64
  let requested = UInt64(requestedLength)
  
  if fileSize < 64 * 1024 * 1024 {
    length = 512 * 1024
  } else if fileSize < 128 * 1024 * 1024 {
    length = 1 * 1024 * 1024
  } else if fileSize < 512 * 1024 * 1024 {
    length = 2 * 1024 * 1024
  } else if fileSize < 1 * 1024 * 1024 * 1024 {
    length = 3 * 1024 * 1024
  } else if fileSize < 2 * 1024 * 1024 * 1024 {
    length = 4 * 1024 * 1024
  } else if fileSize < 4 * 1024 * 1024 * 1024 {
    length = 8 * 1024 * 1024
  } else if fileSize < 8 * 1024 * 1024 * 1024 {
    length = 12 * 1024 * 1024
  } else {
    length = 16 * 1024 * 1024
  }

  return min(length, requested)
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
