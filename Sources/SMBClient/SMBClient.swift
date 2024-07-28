import Foundation

public class SMBClient {
  public let host: String
  public let port: Int
  public var share: String? { session.connectedTree }

  public let session: Session

  public var onDisconnected: (Error) -> Void {
    didSet {
      session.onDisconnected = onDisconnected
    }
  }

  public init(host: String) {
    self.host = host
    port = 445
    session = Session(host: host)
    onDisconnected = { _ in }
  }

  public init(host: String, port: Int) {
    self.host = host
    self.port = port
    session = Session(host: host, port: port)
    onDisconnected = { _ in }
  }

  @discardableResult
  public func login(
    username: String?,
    password: String?,
    domain: String? = nil,
    workstation: String? = nil
  ) async throws -> SessionSetup.Response {
    try await session.negotiate()
    return try await session.sessionSetup(
      username: username,
      password: password,
      domain: domain,
      workstation: workstation
    )
  }

  @discardableResult
  public func logoff() async throws -> Logoff.Response {
    try await session.logoff()
  }

  public func listShares() async throws -> [Share] {
    let shares = try await session.enumShareAll()
    return shares
  }

  @discardableResult
  public func connectShare(_ path: String) async throws -> TreeConnect.Response {
    try await treeConnect(path: path)
  }

  @discardableResult
  public func disconnectShare() async throws -> TreeDisconnect.Response {
    try await treeDisconnect()
  }

  @discardableResult
  public func treeConnect(path: String) async throws -> TreeConnect.Response {
    try await session.treeConnect(path: path)
  }

  @discardableResult
  public func treeDisconnect() async throws -> TreeDisconnect.Response {
    try await session.treeDisconnect()
  }

  public func listDirectory(path: String, pattern: String = "*") async throws -> [File] {
    let files = try await session.queryDirectory(path: Pathname.escape(path), pattern: pattern)
    return files.map { File(fileInfo: $0) }
  }

  public func createDirectory(path: String) async throws {
    try await session.createDirectory(path: Pathname.escape(path))
  }

  public func rename(from: String, to: String) async throws {
    try await move(from: Pathname.escape(from), to: Pathname.escape(to))
  }

  public func move(from: String, to: String) async throws {
    try await session.move(from: Pathname.escape(from), to: Pathname.escape(to))
  }

  public func deleteDirectory(path: String) async throws {
    try await session.deleteDirectory(path: Pathname.escape(path))
  }

  public func deleteFile(path: String) async throws {
    try await session.deleteFile(path: Pathname.escape(path))
  }

  public func fileStat(path: String) async throws -> FileStat {
    let response = try await session.fileStat(path: Pathname.escape(path))
    return FileStat(response)
  }

  public func existFile(path: String) async throws -> Bool {
    try await session.existFile(path: Pathname.escape(path))
  }

  public func existDirectory(path: String) async throws -> Bool {
    try await session.existDirectory(path: Pathname.escape(path))
  }

  public func fileInfo(path: String) async throws -> FileAllInformation {
    let response = try await session.queryInfo(path: Pathname.escape(path))
    return FileAllInformation(data: response.buffer)
  }

  public func download(path: String) async throws -> Data {
    let fileReader = fileReader(path: Pathname.escape(path))

    let data = try await fileReader.download()
    try await fileReader.close()

    return data
  }

  public func upload(content: Data, path: String) async throws {
    try await upload(content: content, path: Pathname.escape(path), progressHandler: { _ in })
  }

  public func upload(content: Data, path: String, progressHandler: (_ progress: Double) -> Void) async throws {
    let fileWriter = fileWriter(path: Pathname.escape(path))

    try await fileWriter.upload(data: content, progressHandler: progressHandler)
    try await fileWriter.close()
  }

  public func upload(fileHandle: FileHandle, path: String) async throws {
    try await upload(fileHandle: fileHandle, path: path, progressHandler: { _ in })
  }

  public func upload(fileHandle: FileHandle, path: String, progressHandler: (_ progress: Double) -> Void) async throws {
    let fileWriter = fileWriter(path: Pathname.escape(path))

    try await fileWriter.upload(fileHandle: fileHandle, progressHandler: progressHandler)
    try await fileWriter.close()
  }

  public func upload(localPath: URL, remotePath path: String) async throws {
    try await upload(localPath: localPath, remotePath: path, progressHandler: { _, _, _ in })
  }

  public func upload(
    localPath: URL,
    remotePath path: String,
    progressHandler: (_ completedFiles: Int, _ fileBeingTransferred: URL, _ bytesSent: Int64) -> Void
  ) async throws {
    let fileWriter = fileWriter(path: Pathname.escape(path))

    try await fileWriter.upload(localPath: localPath, progressHandler: progressHandler)
    try await fileWriter.close()
  }

  public func fileReader(path: String) -> FileReader {
    FileReader(session: session, path: Pathname.escape(path))
  }

  public func fileWriter(path: String) -> FileWriter {
    FileWriter(session: session, path: Pathname.escape(path))
  }

  public func keepAlive() async throws -> Echo.Response {
    try await session.echo()
  }
}

public struct Share {
  public let name: String
  public let comment: String
  public let type: ShareType

  public struct ShareType: OptionSet {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    public static let diskTree = ShareType([])
    public static let printQueue = ShareType(rawValue: SType.printQueue)
    public static let device = ShareType(rawValue: SType.device)
    public static let ipc = ShareType(rawValue: SType.ipc)
    public static let clusterFS = ShareType(rawValue: SType.clusterFS)
    public static let clusterSOFS = ShareType(rawValue: SType.clusterSOFS)
    public static let clusterDFS = ShareType(rawValue: SType.clusterDFS)
    public static let special = ShareType(rawValue: SType.special)
    public static let temporary = ShareType(rawValue: SType.temporary)
  }
}

extension Share: CustomStringConvertible {
  public var description: String {
    "{ name: \(name), comment: \(comment), type: \(type) }"
  }
}

extension Share.ShareType: CustomStringConvertible {
  public var description: String {
    var type = [String]()

    switch rawValue & 0x0FFFFFFF {
    case SType.diskTree:
      type.append("Disk")
    case SType.printQueue:
      type.append("Print Queue")
    case SType.device:
      type.append("Device")
    case SType.ipc:
      type.append("IPC")
    case SType.clusterFS:
      type.append("Cluster FS")
    case SType.clusterDFS:
      type.append("Cluster SOFS")
    case SType.clusterDFS:
      type.append("Cluster DFS")
    default:
      break
    }

    if rawValue & 0x80000000 != 0 {
      type.append("Special")
    }
    if rawValue & 0x40000000 != 0 {
      type.append("Temporary")
    }

    return type.joined(separator: "|")
  }
}

public struct File {
  public let name: String
  public var size: UInt64 { fileStat.size }
  public var isDirectory: Bool { fileStat.isDirectory }
  public var isHidden: Bool { fileStat.isHidden }
  public var isReadOnly: Bool { fileStat.isReadOnly }
  public var isSystem: Bool { fileStat.isSystem }
  public var isArchive: Bool { fileStat.isArchive }
  public var creationTime: Date { fileStat.creationTime }
  public var lastAccessTime: Date { fileStat.lastAccessTime }
  public var lastWriteTime: Date { fileStat.lastWriteTime }
  
  private let fileStat: FileStat

  init(fileInfo: QueryDirectory.FileIdBothDirectoryInformation) {
    name = fileInfo.fileName
    fileStat = FileStat(fileInfo)
  }
}

extension File: CustomStringConvertible {
  public var description: String {
    "{ name: \(name), size: \(size), isDirectory: \(isDirectory), isHidden: \(isHidden), isReadOnly: \(isReadOnly), isSystem: \(isSystem), isArchive: \(isArchive), creationTime: \(creationTime), lastAccessTime: \(lastAccessTime), lastWriteTime: \(lastWriteTime) }"
  }
}

public struct FileStat {
  public let size: UInt64
  public let isDirectory: Bool
  public let isHidden: Bool
  public let isReadOnly: Bool
  public let isSystem: Bool
  public let isArchive: Bool
  public let creationTime: Date
  public let lastAccessTime: Date
  public let lastWriteTime: Date

  init(_ response: Create.Response) {
    size = response.endOfFile
    isDirectory = response.fileAttributes.contains(.directory)
    isHidden = response.fileAttributes.contains(.hidden)
    isReadOnly = response.fileAttributes.contains(.readonly)
    isSystem = response.fileAttributes.contains(.system)
    isArchive = response.fileAttributes.contains(.archive)
    creationTime = FileTime(response.creationTime).date
    lastAccessTime = FileTime(response.lastAccessTime).date
    lastWriteTime = FileTime(response.lastWriteTime).date
  }

  init(_ fileInfo: QueryDirectory.FileIdBothDirectoryInformation) {
    size = fileInfo.endOfFile
    isDirectory = fileInfo.fileAttributes.contains(.directory)
    isHidden = fileInfo.fileAttributes.contains(.hidden)
    isReadOnly = fileInfo.fileAttributes.contains(.readonly)
    isSystem = fileInfo.fileAttributes.contains(.system)
    isArchive = fileInfo.fileAttributes.contains(.archive)
    creationTime = FileTime(fileInfo.creationTime).date
    lastAccessTime = FileTime(fileInfo.lastAccessTime).date
    lastWriteTime = FileTime(fileInfo.lastWriteTime).date
  }
}

extension FileStat: CustomStringConvertible {
  public var description: String {
    "{ size: \(size), isDirectory: \(isDirectory), isHidden: \(isHidden), isReadOnly: \(isReadOnly), isSystem: \(isSystem), isArchive: \(isArchive), creationTime: \(creationTime), lastAccessTime: \(lastAccessTime), lastWriteTime: \(lastWriteTime) }"
  }
}

public struct FileReadResponse {
  public let dataRemaining: UInt32
  public let buffer: Data
  public let endOfFile: Bool
}
