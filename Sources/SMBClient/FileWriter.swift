import Foundation

public class FileWriter {
  private let session: Session
  private let path: String

  private var createResponse: Create.Response?

  init(session: Session, path: String) {
    self.session = session
    self.path = path.precomposedStringWithCanonicalMapping
  }

  public func upload(data: Data) async throws {
    try await upload(data: data, progressHandler: { _ in })
  }

  public func upload(data: Data, progressHandler: (_ progress: Double) -> Void) async throws {
    let fileProxy = try await fileProxy()

    var offset: UInt64 = 0
    while offset < data.count {
      let buffer = data[offset..<min(offset + UInt64(session.maxWriteSize), UInt64(data.count))]

      _ = try await session.write(
        data: buffer,
        fileId: fileProxy.id,
        offset: offset
      )

      offset += UInt64(buffer.count)
      progressHandler(Double(offset) / Double(data.count))
    }
  }

  public func upload(fileHandle: FileHandle) async throws {
    try await upload(fileHandle: fileHandle, progressHandler: { _ in })
  }

  public func upload(fileHandle: FileHandle, progressHandler: (_ progress: Double) -> Void) async throws {
    let fileSize = try fileHandle.fileSize()
    let fileProxy = try await fileProxy()

    while true {
      let offset = UInt64(try fileHandle.offsetInFile())
      let data = fileHandle.readData(ofLength: Int(session.maxWriteSize))
      if data.isEmpty { break }

      _ = try await session.write(
        data: data,
        fileId: fileProxy.id,
        offset: offset
      )

      progressHandler(Double(offset) / Double(fileSize))
    }
  }

  public func upload(localPath: URL) async throws {
    try await upload(localPath: localPath, progressHandler: { _, _, _ in })
  }

  public func upload(
    localPath: URL,
    progressHandler: (_ completedFiles: Int, _ fileBeingTransferred: URL, _ bytesSent: Int64) -> Void
  ) async throws {
    let fileManager = FileManager()

    var isDirectory: ObjCBool = false
    let fileExists = fileManager.fileExists(atPath: localPath.path, isDirectory: &isDirectory)
    guard fileExists else { throw URLError(.fileDoesNotExist) }

    var completedFiles = 0
    var bytesSent: Int64 = 0

    var paths: [(URL, String)] = [(localPath, path)]

    while !paths.isEmpty {
      let (current, destination) = paths.removeFirst()
      var isDirectory: ObjCBool = false
      let fileExists = fileManager.fileExists(atPath: current.path, isDirectory: &isDirectory)
      guard fileExists else { throw URLError(.fileDoesNotExist) }

      if isDirectory.boolValue {
        try await session.createDirectory(path: destination)

        let contents = try fileManager.contentsOfDirectory(at: current, includingPropertiesForKeys: nil)
        paths.append(contentsOf: contents.map { ($0, "\(destination)/\($0.lastPathComponent)") })
      } else {
        progressHandler(completedFiles, current, bytesSent)

        let fileHandle = try FileHandle(forReadingFrom: current)

        let fileWriter = FileWriter(session: session, path: destination)
        try await fileWriter.upload(fileHandle: fileHandle)
        try await fileWriter.close()

        completedFiles += 1
        bytesSent += Int64(try fileHandle.offsetInFile())
        progressHandler(completedFiles, current, bytesSent)
      }
    }
  }

  public func close() async throws {
    if let createResponse {
      try await session.close(fileId: createResponse.fileId)
    }
    createResponse = nil
  }

  private func fileProxy() async throws -> FileProxy {
    guard let createResponse else {
      let response = try await session.create(
        desiredAccess: [
          .readData,
          .writeData,
          .appendData,
          .readAttributes,
          .readControl,
          .writeDac
        ],
        fileAttributes: [.archive, .normal],
        shareAccess: [.read, .write, .delete],
        createDisposition: .create,
        createOptions: [],
        name: path
      )
      createResponse = response
      return FileProxy(id: response.fileId, size: response.endOfFile)
    }

    return FileProxy(id: createResponse.fileId, size: createResponse.endOfFile)
  }
}

extension FileHandle {
  func offsetInFile() throws -> UInt64 {
    if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
      return try offset()
    } else {
      return offsetInFile
    }
  }

  func fileSize() throws -> UInt64 {
    let currentOffset: UInt64
    let fileSize: UInt64

    if #available(macOS 10.15.4, iOS 13.4, watchOS 6.2, tvOS 13.4, *) {
      currentOffset = try offset()
      fileSize = try seekToEnd()
    } else {
      currentOffset = offsetInFile
      fileSize = seekToEndOfFile()
    }

    seek(toFileOffset: currentOffset)

    return fileSize
  }
}
