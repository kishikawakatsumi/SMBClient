import Foundation

/// An SMB (Server Message Block) client that provides file sharing operations over a network.
///
/// `SMBClient` is the main entry point for interacting with SMB file servers. It supports
/// connecting to SMB shares, browsing directories, and transferring files using the SMB2/3 protocol.
///
/// ## Usage
///
/// ```swift
/// let client = SMBClient(host: "192.168.1.100")
/// try await client.login(username: "user", password: "pass")
/// try await client.connectShare("SharedFolder")
///
/// let files = try await client.listDirectory(path: "")
/// for file in files {
///     print(file.name)
/// }
///
/// try await client.logoff()
/// ```
public class SMBClient {
  /// The hostname or IP address of the SMB server.
  public let host: String
  /// The TCP port number used for the SMB connection. Defaults to `445`.
  public let port: Int
  /// The name of the currently connected share, or `nil` if no share is connected.
  public var share: String? { session.connectedTree }

  /// The underlying SMB session that manages the protocol-level communication.
  public let session: Session

  /// A closure that is called when the connection to the server is unexpectedly lost.
  ///
  /// Set this property to handle disconnection events and perform cleanup or reconnection logic.
  public var onDisconnected: (Error) -> Void {
    didSet {
      session.onDisconnected = onDisconnected
    }
  }

  /// Creates a new SMB client that connects to the specified host on the default port (445).
  ///
  /// - Parameter host: The hostname or IP address of the SMB server.
  public init(host: String) {
    self.host = host
    port = 445
    session = Session(host: host)
    onDisconnected = { _ in }
  }

  /// Creates a new SMB client that connects to the specified host and port.
  ///
  /// - Parameters:
  ///   - host: The hostname or IP address of the SMB server.
  ///   - port: The TCP port number to connect to.
  public init(host: String, port: Int) {
    self.host = host
    self.port = port
    session = Session(host: host, port: port)
    onDisconnected = { _ in }
  }

  /// Authenticates with the SMB server using the provided credentials.
  ///
  /// This method performs SMB negotiation and session setup in sequence.
  /// It must be called before any file operations can be performed.
  ///
  /// - Parameters:
  ///   - username: The username for authentication, or `nil` for anonymous access.
  ///   - password: The password for authentication, or `nil` for anonymous access.
  ///   - domain: The Windows domain name. Defaults to `nil`.
  ///   - workstation: The client workstation name. Defaults to `nil`.
  ///   - requireSigning: Whether to require message signing. Defaults to `false`.
  /// - Returns: The session setup response from the server.
  /// - Throws: An error if negotiation or authentication fails.
  @discardableResult
  public func login(
    username: String?,
    password: String?,
    domain: String? = nil,
    workstation: String? = nil,
    requireSigning: Bool = false
  ) async throws -> SessionSetup.Response {
    try await session.negotiate(securityMode: [requireSigning ? .signingRequired : .signingEnabled])
    return try await session.sessionSetup(
      username: username,
      password: password,
      domain: domain,
      workstation: workstation,
      requireSigning: requireSigning
    )
  }

  /// Logs off from the SMB server and ends the current session.
  ///
  /// - Returns: The logoff response from the server.
  /// - Throws: An error if the logoff request fails.
  @discardableResult
  public func logoff() async throws -> Logoff.Response {
    try await session.logoff()
  }

  /// Lists all available shares on the SMB server.
  ///
  /// - Returns: An array of ``Share`` objects representing the available network shares.
  /// - Throws: An error if the share enumeration fails.
  public func listShares() async throws -> [Share] {
    let shares = try await session.enumShareAll()
    return shares
  }

  /// Connects to the specified SMB share.
  ///
  /// This is a convenience alias for ``treeConnect(path:)``.
  ///
  /// - Parameter path: The name of the share to connect to.
  /// - Returns: The tree connect response from the server.
  /// - Throws: An error if the connection to the share fails.
  @discardableResult
  public func connectShare(_ path: String) async throws -> TreeConnect.Response {
    try await treeConnect(path: path)
  }

  /// Disconnects from the currently connected share.
  ///
  /// This is a convenience alias for ``treeDisconnect()``.
  ///
  /// - Returns: The tree disconnect response from the server.
  /// - Throws: An error if the disconnection fails.
  @discardableResult
  public func disconnectShare() async throws -> TreeDisconnect.Response {
    try await treeDisconnect()
  }

  /// Connects to the specified SMB share using a tree connect request.
  ///
  /// - Parameter path: The name of the share to connect to.
  /// - Returns: The tree connect response from the server.
  /// - Throws: An error if the connection to the share fails.
  @discardableResult
  public func treeConnect(path: String) async throws -> TreeConnect.Response {
    try await session.treeConnect(path: path)
  }

  /// Disconnects from the currently connected share using a tree disconnect request.
  ///
  /// - Returns: The tree disconnect response from the server.
  /// - Throws: An error if the disconnection fails.
  @discardableResult
  public func treeDisconnect() async throws -> TreeDisconnect.Response {
    try await session.treeDisconnect()
  }

  /// Lists the contents of a directory on the connected share.
  ///
  /// - Parameters:
  ///   - path: The path of the directory to list, relative to the share root.
  ///     Use an empty string (`""`) for the share root.
  ///   - pattern: A wildcard pattern to filter the results. Defaults to `"*"` (all files).
  /// - Returns: An array of ``File`` objects representing the directory entries.
  /// - Throws: An error if the directory listing fails.
  public func listDirectory(path: String, pattern: String = "*") async throws -> [File] {
    let files = try await session.queryDirectory(path: Pathname.normalize(path), pattern: pattern)
    return files.map { File(fileInfo: $0) }
  }

  /// Creates a new directory on the connected share.
  ///
  /// - Parameter path: The path of the directory to create, relative to the share root.
  /// - Throws: An error if the directory creation fails.
  public func createDirectory(path: String) async throws {
    try await session.createDirectory(path: Pathname.normalize(path.precomposedStringWithCanonicalMapping))
  }

  /// Renames a file or directory on the connected share.
  ///
  /// This is an alias for ``move(from:to:)``.
  ///
  /// - Parameters:
  ///   - from: The current path of the file or directory.
  ///   - to: The new path for the file or directory.
  /// - Throws: An error if the rename operation fails.
  public func rename(from: String, to: String) async throws {
    try await move(from: Pathname.normalize(from), to: Pathname.normalize(to))
  }

  /// Moves or renames a file or directory on the connected share.
  ///
  /// - Parameters:
  ///   - from: The current path of the file or directory.
  ///   - to: The destination path for the file or directory.
  /// - Throws: An error if the move operation fails.
  public func move(from: String, to: String) async throws {
    try await session.move(from: Pathname.normalize(from), to: Pathname.normalize(to.precomposedStringWithCanonicalMapping))
  }

  /// Deletes a directory on the connected share.
  ///
  /// The directory must be empty before it can be deleted.
  ///
  /// - Parameter path: The path of the directory to delete, relative to the share root.
  /// - Throws: An error if the directory deletion fails.
  public func deleteDirectory(path: String) async throws {
    try await session.deleteDirectory(path: Pathname.normalize(path))
  }

  /// Deletes a file on the connected share.
  ///
  /// - Parameter path: The path of the file to delete, relative to the share root.
  /// - Throws: An error if the file deletion fails.
  public func deleteFile(path: String) async throws {
    try await session.deleteFile(path: Pathname.normalize(path))
  }

  /// Retrieves file statistics for a file or directory on the connected share.
  ///
  /// - Parameter path: The path of the file or directory, relative to the share root.
  /// - Returns: A ``FileStat`` containing size, attributes, and timestamps.
  /// - Throws: An error if the file stat query fails.
  public func fileStat(path: String) async throws -> FileStat {
    let response = try await session.fileStat(path: Pathname.normalize(path))
    return FileStat(response)
  }

  /// Checks whether a file exists at the specified path on the connected share.
  ///
  /// - Parameter path: The path of the file, relative to the share root.
  /// - Returns: `true` if the file exists, `false` otherwise.
  /// - Throws: An error if the existence check fails.
  public func existFile(path: String) async throws -> Bool {
    try await session.existFile(path: Pathname.normalize(path))
  }

  /// Checks whether a directory exists at the specified path on the connected share.
  ///
  /// - Parameter path: The path of the directory, relative to the share root.
  /// - Returns: `true` if the directory exists, `false` otherwise.
  /// - Throws: An error if the existence check fails.
  public func existDirectory(path: String) async throws -> Bool {
    try await session.existDirectory(path: Pathname.normalize(path))
  }

  /// Retrieves detailed file information for a file or directory on the connected share.
  ///
  /// - Parameter path: The path of the file or directory, relative to the share root.
  /// - Returns: A `FileAllInformation` object containing comprehensive file metadata.
  /// - Throws: An error if the query fails.
  public func fileInfo(path: String) async throws -> FileAllInformation {
    let response = try await session.queryInfo(path: Pathname.normalize(path))
    return FileAllInformation(data: response.buffer)
  }

  /// Downloads a file from the connected share into memory.
  ///
  /// - Parameter path: The path of the file to download, relative to the share root.
  /// - Returns: The file contents as `Data`.
  /// - Throws: An error if the download fails.
  public func download(path: String) async throws -> Data {
    return try await download(path: path, progressHandler: { _ in })
  }

  /// Downloads a file from the connected share into memory with progress reporting.
  ///
  /// - Parameters:
  ///   - path: The path of the file to download, relative to the share root.
  ///   - progressHandler: A closure called periodically with a progress value between `0.0` and `1.0`.
  /// - Returns: The file contents as `Data`.
  /// - Throws: An error if the download fails.
  public func download(path: String, progressHandler: (_ progress: Double) -> Void) async throws -> Data {
    let fileReader = fileReader(path: Pathname.normalize(path))

    let data = try await fileReader.download(progressHandler: progressHandler)
    try await fileReader.close()

    return data
  }

  /// Downloads a file from the connected share to a local file path.
  ///
  /// - Parameters:
  ///   - path: The path of the file to download, relative to the share root.
  ///   - localPath: The local file URL where the downloaded file will be saved.
  ///   - overwrite: Whether to overwrite an existing file at the local path. Defaults to `false`.
  ///   - progressHandler: A closure called periodically with a progress value between `0.0` and `1.0`.
  /// - Throws: An error if the download fails.
  public func download(path: String, localPath: URL, overwrite: Bool = false, progressHandler: (_ progress: Double) -> Void = { _ in }) async throws {
    let fileReader = fileReader(path: Pathname.normalize(path))
    
    try await fileReader.download(to: localPath, overwrite: overwrite, progressHandler: progressHandler)
    try await fileReader.close()
  }

  /// Uploads data to a file on the connected share.
  ///
  /// - Parameters:
  ///   - content: The data to upload.
  ///   - path: The destination file path on the share, relative to the share root.
  /// - Throws: An error if the upload fails.
  public func upload(content: Data, path: String) async throws {
    try await upload(content: content, path: Pathname.normalize(path), progressHandler: { _ in })
  }

  /// Uploads data to a file on the connected share with progress reporting.
  ///
  /// - Parameters:
  ///   - content: The data to upload.
  ///   - path: The destination file path on the share, relative to the share root.
  ///   - progressHandler: A closure called periodically with a progress value between `0.0` and `1.0`.
  /// - Throws: An error if the upload fails.
  public func upload(content: Data, path: String, progressHandler: (_ progress: Double) -> Void) async throws {
    let fileWriter = fileWriter(path: Pathname.normalize(path))

    try await fileWriter.upload(data: content, progressHandler: progressHandler)
    try await fileWriter.close()
  }

  /// Uploads data from a file handle to a file on the connected share.
  ///
  /// - Parameters:
  ///   - fileHandle: The local file handle to read from.
  ///   - path: The destination file path on the share, relative to the share root.
  /// - Throws: An error if the upload fails.
  public func upload(fileHandle: FileHandle, path: String) async throws {
    try await upload(fileHandle: fileHandle, path: path, progressHandler: { _ in })
  }

  /// Uploads data from a file handle to a file on the connected share with progress reporting.
  ///
  /// - Parameters:
  ///   - fileHandle: The local file handle to read from.
  ///   - path: The destination file path on the share, relative to the share root.
  ///   - progressHandler: A closure called periodically with a progress value between `0.0` and `1.0`.
  /// - Throws: An error if the upload fails.
  public func upload(fileHandle: FileHandle, path: String, progressHandler: (_ progress: Double) -> Void) async throws {
    let path = Pathname.normalize(path)
    let fileWriter = fileWriter(path: path)

    try await fileWriter.upload(fileHandle: fileHandle, progressHandler: progressHandler)
    try await fileWriter.close()

    await fileWriter.restoreFileAttributes(fileHandle, path)
  }

  /// Uploads a local file or directory to the connected share.
  ///
  /// If `localPath` is a directory, its entire contents are uploaded recursively.
  ///
  /// - Parameters:
  ///   - localPath: The URL of the local file or directory to upload.
  ///   - path: The destination path on the share, relative to the share root.
  /// - Throws: An error if the upload fails.
  public func upload(localPath: URL, remotePath path: String) async throws {
    try await upload(localPath: localPath, remotePath: path, progressHandler: { _, _, _ in })
  }

  /// Uploads a local file or directory to the connected share with progress reporting.
  ///
  /// If `localPath` is a directory, its entire contents are uploaded recursively.
  ///
  /// - Parameters:
  ///   - localPath: The URL of the local file or directory to upload.
  ///   - path: The destination path on the share, relative to the share root.
  ///   - progressHandler: A closure called with the number of completed files,
  ///     the URL of the file currently being transferred, and the number of bytes sent.
  /// - Throws: An error if the upload fails.
  public func upload(
    localPath: URL,
    remotePath path: String,
    progressHandler: (_ completedFiles: Int, _ fileBeingTransferred: URL, _ bytesSent: Int64) -> Void
  ) async throws {
    let fileWriter = fileWriter(path: Pathname.normalize(path))

    try await fileWriter.upload(localPath: localPath, progressHandler: progressHandler)
    try await fileWriter.close()
  }

  /// Creates a ``FileReader`` for reading a file on the connected share.
  ///
  /// Use a `FileReader` for efficient, incremental reading of large files.
  ///
  /// - Parameter path: The path of the file to read, relative to the share root.
  /// - Returns: A new ``FileReader`` instance.
  public func fileReader(path: String) -> FileReader {
    FileReader(session: session, path: Pathname.normalize(path))
  }

  /// Creates a ``FileWriter`` for writing to a file on the connected share.
  ///
  /// Use a `FileWriter` for efficient, incremental writing of large files or directory uploads.
  ///
  /// - Parameter path: The path of the file to write, relative to the share root.
  /// - Returns: A new ``FileWriter`` instance.
  public func fileWriter(path: String) -> FileWriter {
    FileWriter(session: session, path: Pathname.normalize(path))
  }

  /// Creates a ``TreeAccessor`` for accessing a specific share with an independent session.
  ///
  /// Use a `TreeAccessor` when you need to work with multiple shares simultaneously,
  /// as each accessor maintains its own session context.
  ///
  /// - Parameter share: The name of the share to access.
  /// - Returns: A new ``TreeAccessor`` instance.
  public func treeAccessor(share: String) -> TreeAccessor {
    session.treeAccessor(share: share)
  }

  /// Returns the available disk space on the connected share in bytes.
  ///
  /// - Returns: The number of available bytes on the share.
  /// - Throws: An error if the query fails.
  public func availableSpace() async throws -> UInt64 {
    let response = try await session.queryInfo(path: "", infoType: .fileSystem, fileInfoClass: .fileFsSizeInformation)

    let sizeInformation = FileFsSizeInformation(data: response.buffer)
    let availableAllocationUnits = sizeInformation.availableAllocationUnits
    let sectorsPerAllocationUnit = sizeInformation.sectorsPerAllocationUnit
    let bytesPerSector = sizeInformation.bytesPerSector

    let bytesPerAllocationUnit = UInt64(sectorsPerAllocationUnit * bytesPerSector)
    let availableSpaceBytes = availableAllocationUnits * bytesPerAllocationUnit

    return availableSpaceBytes
  }

  /// Sends an echo request to keep the connection alive.
  ///
  /// Use this method periodically to prevent the server from closing an idle connection.
  ///
  /// - Returns: The echo response from the server.
  /// - Throws: An error if the echo request fails.
  public func keepAlive() async throws -> Echo.Response {
    try await session.echo()
  }
}

/// Represents an SMB network share exposed by the server.
public struct Share: Hashable {
  /// The name of the share.
  public let name: String
  /// A descriptive comment associated with the share.
  public let comment: String
  /// The type of the share (e.g., disk, printer, IPC).
  public let type: ShareType

  /// Describes the type of an SMB share as an option set.
  public struct ShareType: OptionSet, Hashable {
    public let rawValue: UInt32

    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    /// A standard disk share.
    public static let diskTree = ShareType([])
    /// A print queue share.
    public static let printQueue = ShareType(rawValue: SType.printQueue)
    /// A communication device share.
    public static let device = ShareType(rawValue: SType.device)
    /// An inter-process communication (IPC) share.
    public static let ipc = ShareType(rawValue: SType.ipc)
    /// A cluster file system share.
    public static let clusterFS = ShareType(rawValue: SType.clusterFS)
    /// A scale-out cluster file system share.
    public static let clusterSOFS = ShareType(rawValue: SType.clusterSOFS)
    /// A DFS (Distributed File System) cluster share.
    public static let clusterDFS = ShareType(rawValue: SType.clusterDFS)
    /// A special hidden share (e.g., `IPC$`, `ADMIN$`).
    public static let special = ShareType(rawValue: SType.special)
    /// A temporary share.
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

/// Represents a file or directory entry returned from a directory listing.
public struct File: Hashable {
  /// The name of the file or directory.
  public let name: String
  /// The file size in bytes. Returns `0` for directories.
  public var size: UInt64 { fileStat.size }
  /// Whether this entry is a directory.
  public var isDirectory: Bool { fileStat.isDirectory }
  /// Whether the file or directory is hidden.
  public var isHidden: Bool { fileStat.isHidden }
  /// Whether the file or directory is read-only.
  public var isReadOnly: Bool { fileStat.isReadOnly }
  /// Whether the file or directory is a system file.
  public var isSystem: Bool { fileStat.isSystem }
  /// Whether the file has the archive attribute set.
  public var isArchive: Bool { fileStat.isArchive }
  /// The date and time when the file or directory was created.
  public var creationTime: Date { fileStat.creationTime }
  /// The date and time when the file or directory was last accessed.
  public var lastAccessTime: Date { fileStat.lastAccessTime }
  /// The date and time when the file or directory was last written to.
  public var lastWriteTime: Date { fileStat.lastWriteTime }
  
  private let fileStat: FileStat

  init(fileInfo: FileDirectoryInformation) {
    name = fileInfo.fileName
    fileStat = FileStat(fileInfo)
  }
}

extension File: CustomStringConvertible {
  public var description: String {
    "{ name: \(name), size: \(size), isDirectory: \(isDirectory), isHidden: \(isHidden), isReadOnly: \(isReadOnly), isSystem: \(isSystem), isArchive: \(isArchive), creationTime: \(creationTime), lastAccessTime: \(lastAccessTime), lastWriteTime: \(lastWriteTime) }"
  }
}

/// Contains file statistics including size, attributes, and timestamps.
public struct FileStat: Hashable {
  /// The file size in bytes.
  public let size: UInt64
  /// Whether this entry is a directory.
  public let isDirectory: Bool
  /// Whether the file or directory is hidden.
  public let isHidden: Bool
  /// Whether the file or directory is read-only.
  public let isReadOnly: Bool
  /// Whether the file or directory is a system file.
  public let isSystem: Bool
  /// Whether the file has the archive attribute set.
  public let isArchive: Bool
  /// The date and time when the file or directory was created.
  public let creationTime: Date
  /// The date and time when the file or directory was last accessed.
  public let lastAccessTime: Date
  /// The date and time when the file or directory was last written to.
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

  init(_ fileInfo: FileDirectoryInformation) {
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
