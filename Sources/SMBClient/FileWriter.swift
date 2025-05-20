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

    progressHandler(1.0)
  }

  public func upload(localPath: URL) async throws {
    try await upload(localPath: localPath, progressHandler: { _, _, _ in })
  }

  public func upload(
    localPath: URL,
    progressHandler: (_ completedFiles: Int, _ fileBeingTransferred: URL, _ bytesSent: Int64) -> Void
  ) async throws {
    enum Action {
      case enterDirectory(URL, String)
      case exitDirectory(URL, String)
      case file(URL, String)
    }

    let fileManager = FileManager()

    var isDirectory: ObjCBool = false
    let fileExists = fileManager.fileExists(atPath: localPath.path, isDirectory: &isDirectory)
    guard fileExists else { throw URLError(.fileDoesNotExist) }

    var paths: [Action] = isDirectory.boolValue ? [.enterDirectory(localPath, path)] : [.file(localPath, path)]

    var completedFiles = 0
    var bytesSent: Int64 = 0

    while let job = paths.popLast() {
      switch job {
      case let .enterDirectory(source, destination):
        try await session.createDirectory(path: destination)

        paths.append(.exitDirectory(source, destination))

        let children = try fileManager.contentsOfDirectory(at: source, includingPropertiesForKeys: nil)
        paths.append(
          contentsOf: children.reversed().map { (child) in
            var isDirectory: ObjCBool = false
            fileManager.fileExists(atPath: child.path, isDirectory: &isDirectory)

            let destination = "\(destination)/\(child.lastPathComponent)"
            return isDirectory.boolValue ? .enterDirectory(child, destination) : .file(child, destination)
          }
        )
      case let .exitDirectory(source, destination):
        await restoreFileAttributes(source, destination)
      case let .file(source, destination):
        progressHandler(completedFiles, source, bytesSent)

        let fileHandle = try FileHandle(forReadingFrom: source)
        let writer = FileWriter(session: session, path: destination)
        try await writer.upload(fileHandle: fileHandle)
        try await writer.close()

        await restoreFileAttributes(source, destination)

        completedFiles += 1
        bytesSent += Int64(try fileHandle.offsetInFile())
        progressHandler(completedFiles, source, bytesSent)
      }
    }
  }

  public func close() async throws {
    if let createResponse {
      try await session.close(fileId: createResponse.fileId)
    }
    createResponse = nil
  }

  private func restoreFileAttributes(_ current: URL, _ destination: String) async {
    let attributes = try? FileManager().attributesOfItem(atPath: current.path)

    let now = Date()
    let creationDate  = attributes?[.creationDate] as? Date ?? now
    let modificationDate = attributes?[.modificationDate] as? Date ?? now

    _ = try? await session.setInfo(
      path: destination,
      FileBasicInformation(
        creationTime: FileTime(creationDate).raw,
        lastAccessTime: FileTime(now).raw,
        lastWriteTime: FileTime(modificationDate).raw,
        changeTime: 0,
        fileAttributes: [.archive]
      )
    )
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
