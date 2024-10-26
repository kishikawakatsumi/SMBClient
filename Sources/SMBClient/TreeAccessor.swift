import Foundation

public class TreeAccessor {
  public let share: String
  private let session: Session

  init(session: Session, share: String) {
    self.session = session.newSession()
    self.share = share
  }

  deinit {
    let session = self.session
    Task {
      try await session.treeDisconnect()
    }
  }

  public func listDirectory(path: String, pattern: String = "*") async throws -> [File] {
    let files = try await session().queryDirectory(path: Pathname.normalize(path), pattern: pattern)
    return files.map { File(fileInfo: $0) }
  }

  public func createDirectory(share: String? = nil, path: String) async throws {
    try await session().createDirectory(path: Pathname.normalize(path.precomposedStringWithCanonicalMapping))
  }

  public func rename(share: String? = nil, from: String, to: String) async throws {
    try await move(share: share, from: Pathname.normalize(from), to: Pathname.normalize(to))
  }

  public func move(share: String? = nil, from: String, to: String) async throws {
    try await session().move(from: Pathname.normalize(from), to: Pathname.normalize(to.precomposedStringWithCanonicalMapping))
  }

  public func deleteDirectory(share: String? = nil, path: String) async throws {
    try await session().deleteDirectory(path: Pathname.normalize(path))
  }

  public func deleteFile(share: String? = nil, path: String) async throws {
    try await session().deleteFile(path: Pathname.normalize(path))
  }

  public func fileStat(share: String? = nil, path: String) async throws -> FileStat {
    let response = try await session().fileStat(path: Pathname.normalize(path))
    return FileStat(response)
  }

  public func existFile(share: String? = nil, path: String) async throws -> Bool {
    try await session().existFile(path: Pathname.normalize(path))
  }

  public func existDirectory(share: String? = nil, path: String) async throws -> Bool {
    try await session().existDirectory(path: Pathname.normalize(path))
  }

  public func fileInfo(share: String? = nil, path: String) async throws -> FileAllInformation {
    let response = try await session().queryInfo(path: Pathname.normalize(path))
    return FileAllInformation(data: response.buffer)
  }

  public func download(share: String? = nil, path: String) async throws -> Data {
    let fileReader = fileReader(path: Pathname.normalize(path))

    let data = try await fileReader.download()
    try await fileReader.close()

    return data
  }

  public func upload(share: String? = nil, content: Data, path: String) async throws {
    try await upload(share: share, content: content, path: Pathname.normalize(path), progressHandler: { _ in })
  }

  public func upload(share: String? = nil, content: Data, path: String, progressHandler: (_ progress: Double) -> Void) async throws {
    let fileWriter = fileWriter(share: share, path: Pathname.normalize(path))

    try await fileWriter.upload(data: content, progressHandler: progressHandler)
    try await fileWriter.close()
  }

  public func upload(share: String? = nil, fileHandle: FileHandle, path: String) async throws {
    try await upload(share: share, fileHandle: fileHandle, path: path, progressHandler: { _ in })
  }

  public func upload(share: String? = nil, fileHandle: FileHandle, path: String, progressHandler: (_ progress: Double) -> Void) async throws {
    let fileWriter = fileWriter(share: share, path: Pathname.normalize(path))

    try await fileWriter.upload(fileHandle: fileHandle, progressHandler: progressHandler)
    try await fileWriter.close()
  }

  public func upload(share: String? = nil, localPath: URL, remotePath path: String) async throws {
    try await upload(share: share, localPath: localPath, remotePath: path, progressHandler: { _, _, _ in })
  }

  public func upload(
    share: String? = nil,
    localPath: URL,
    remotePath path: String,
    progressHandler: (_ completedFiles: Int, _ fileBeingTransferred: URL, _ bytesSent: Int64) -> Void
  ) async throws {
    let fileWriter = fileWriter(share: share, path: Pathname.normalize(path))

    try await fileWriter.upload(localPath: localPath, progressHandler: progressHandler)
    try await fileWriter.close()
  }

  public func fileReader(share: String? = nil, path: String) -> FileReader {
    FileReader(session: session, path: Pathname.normalize(path))
  }

  public func fileWriter(share: String? = nil, path: String) -> FileWriter {
    FileWriter(session: session, path: Pathname.normalize(path))
  }

  public func availableSpace() async throws -> UInt64 {
    let response = try await session().queryInfo(path: "", infoType: .fileSystem, fileInfoClass: .fileFsSizeInformation)

    let sizeInformation = FileFsSizeInformation(data: response.buffer)
    let availableAllocationUnits = sizeInformation.availableAllocationUnits
    let sectorsPerAllocationUnit = sizeInformation.sectorsPerAllocationUnit
    let bytesPerSector = sizeInformation.bytesPerSector

    let bytesPerAllocationUnit = UInt64(sectorsPerAllocationUnit * bytesPerSector)
    let availableSpaceBytes = availableAllocationUnits * bytesPerAllocationUnit

    return availableSpaceBytes
  }

  public func keepAlive() async throws -> Echo.Response {
    try await session().echo()
  }

  func session() async throws -> Session {
    if session.treeId == 0 {
      try await session.treeConnect(path: share)
    }
    return session
  }
}
