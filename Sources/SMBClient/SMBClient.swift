import Foundation

/// A client for connecting to and interacting with SMB (Server Message Block) file servers.
///
/// `SMBClient` provides a high-level API for performing common SMB operations such as
/// listing shares and directories, uploading and downloading files, creating and deleting
/// files and directories, and querying file metadata.
///
/// ## Usage
///
/// ```swift
/// let client = SMBClient(host: "192.168.1.1")
/// try await client.login(username: "user", password: "password")
/// try await client.connectShare("SharedDocs")
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

  /// The TCP port used to connect to the SMB server. Defaults to `445`.
  public let port: Int

  /// The name of the share currently connected via `connectShare(_:)` or `treeConnect(path:)`,
  /// or `nil` if no share is connected.
  public var share: String? { session.connectedTree }

  /// The underlying SMB session that manages the network connection and protocol state.
  public let session: Session

  /// A closure called when the connection to the server is unexpectedly lost.
  ///
  /// Assign a handler to be notified of disconnection events. The closure receives the
  /// error that caused the disconnection.
  public var onDisconnected: (Error) -> Void {
    didSet {
      session.onDisconnected = onDisconnected
    }
  }

  /// Creates a new SMB client that connects to the given host on the default SMB port (445).
  ///
  /// - Parameter host: The hostname or IP address of the SMB server.
  public init(host: String) {
    self.host = host
    port = 445
    session = Session(host: host)
    onDisconnected = { _ in }
  }

  /// Creates a new SMB client that connects to the given host on the specified port.
  ///
  /// - Parameters:
  ///   - host: The hostname or IP address of the SMB server.
  ///   - port: The TCP port to connect on.
  public init(host: String, port: Int) {
    self.host = host
    self.port = port
    session = Session(host: host, port: port)
    onDisconnected = { _ in }
  }

  /// Authenticates with the SMB server using the provided credentials.
  ///
  /// This method first performs an SMB negotiate handshake and then a session setup
  /// using NTLM authentication. Call this after initializing the client and before
  /// any file operations.
  ///
  /// - Parameters:
  ///   - username: The username to authenticate with, or `nil` for anonymous/guest access.
  ///   - password: The password for the given username, or `nil` for anonymous/guest access.
  ///   - domain: The authentication domain. Defaults to `nil`.
  ///   - workstation: The workstation name used in NTLM negotiation. Defaults to `nil`.
  ///   - requireSigning: When `true`, requires the server to sign all messages. Defaults to `false`.
  /// - Returns: The server's session setup response.
  /// - Throws: An error if the network connection fails or authentication is rejected.
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

  /// Ends the authenticated session with the SMB server.
  ///
  /// - Returns: The server's logoff response.
  /// - Throws: An error if the logoff request fails.
  @discardableResult
  public func logoff() async throws -> Logoff.Response {
    try await session.logoff()
  }

  /// Returns the list of shares available on the server.
  ///
  /// - Returns: An array of ``Share`` values describing each available share.
  /// - Throws: An error if the server cannot be queried or the session is not authenticated.
  public func listShares() async throws -> [Share] {
    let shares = try await session.enumShareAll()
    return shares
  }

  /// Connects to the named share on the server.
  ///
  /// This is a convenience wrapper around ``treeConnect(path:)``. Subsequent file
  /// operations will target this share until ``disconnectShare()`` is called.
  ///
  /// - Parameter path: The share name or UNC path (e.g. `"Documents"` or `"\\server\Documents"`).
  /// - Returns: The server's tree connect response.
  /// - Throws: An error if the share cannot be found or access is denied.
  @discardableResult
  public func connectShare(_ path: String) async throws -> TreeConnect.Response {
    try await treeConnect(path: path)
  }

  /// Disconnects from the currently connected share.
  ///
  /// - Returns: The server's tree disconnect response.
  /// - Throws: An error if no share is connected or the disconnect request fails.
  @discardableResult
  public func disconnectShare() async throws -> TreeDisconnect.Response {
    try await treeDisconnect()
  }

  /// Sends an SMB2 TREE_CONNECT request to connect to the specified share path.
  ///
  /// - Parameter path: The share name or UNC path to connect to.
  /// - Returns: The server's tree connect response.
  /// - Throws: An error if the connection to the share fails.
  @discardableResult
  public func treeConnect(path: String) async throws -> TreeConnect.Response {
    try await session.treeConnect(path: path)
  }

  /// Sends an SMB2 TREE_DISCONNECT request to disconnect from the currently connected share.
  ///
  /// - Returns: The server's tree disconnect response.
  /// - Throws: An error if the disconnect request fails.
  @discardableResult
  public func treeDisconnect() async throws -> TreeDisconnect.Response {
    try await session.treeDisconnect()
  }

  /// Lists the contents of a directory on the connected share.
  ///
  /// - Parameters:
  ///   - path: The path of the directory relative to the connected share root.
  ///   - pattern: A wildcard pattern used to filter results. Defaults to `"*"` (all entries).
  /// - Returns: An array of ``File`` values for each matching entry in the directory.
  /// - Throws: An error if the directory cannot be opened or queried.
  public func listDirectory(path: String, pattern: String = "*") async throws -> [File] {
    let files = try await session.queryDirectory(path: Pathname.normalize(path), pattern: pattern)
    return files.map { File(fileInfo: $0) }
  }

  /// Creates a new directory at the specified path on the connected share.
  ///
  /// - Parameter path: The path of the directory to create, relative to the share root.
  /// - Throws: An error if the directory already exists or cannot be created.
  public func createDirectory(path: String) async throws {
    try await session.createDirectory(path: Pathname.normalize(path.precomposedStringWithCanonicalMapping))
  }

  /// Renames a file or directory on the connected share.
  ///
  /// This is a convenience wrapper around ``move(from:to:)``.
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

  /// Deletes a directory at the specified path on the connected share.
  ///
  /// - Parameter path: The path of the directory to delete, relative to the share root.
  /// - Throws: An error if the directory does not exist or cannot be deleted.
  public func deleteDirectory(path: String) async throws {
    try await session.deleteDirectory(path: Pathname.normalize(path))
  }

  /// Deletes a file at the specified path on the connected share.
  ///
  /// - Parameter path: The path of the file to delete, relative to the share root.
  /// - Throws: An error if the file does not exist or cannot be deleted.
  public func deleteFile(path: String) async throws {
    try await session.deleteFile(path: Pathname.normalize(path))
  }

  /// Returns basic status information about the file or directory at the given path.
  ///
  /// - Parameter path: The path of the file or directory, relative to the share root.
  /// - Returns: A ``FileStat`` value containing size and attribute information.
  /// - Throws: An error if the path does not exist or cannot be queried.
  public func fileStat(path: String) async throws -> FileStat {
    let response = try await session.fileStat(path: Pathname.normalize(path))
    return FileStat(response)
  }

  /// Returns whether a file exists at the given path on the connected share.
  ///
  /// - Parameter path: The path to check, relative to the share root.
  /// - Returns: `true` if a file exists at the path; `false` otherwise.
  /// - Throws: An error if the check cannot be performed due to a network or protocol error.
  public func existFile(path: String) async throws -> Bool {
    try await session.existFile(path: Pathname.normalize(path))
  }

  /// Returns whether a directory exists at the given path on the connected share.
  ///
  /// - Parameter path: The path to check, relative to the share root.
  /// - Returns: `true` if a directory exists at the path; `false` otherwise.
  /// - Throws: An error if the check cannot be performed due to a network or protocol error.
  public func existDirectory(path: String) async throws -> Bool {
    try await session.existDirectory(path: Pathname.normalize(path))
  }

  /// Returns detailed file information for the item at the given path.
  ///
  /// - Parameter path: The path of the file or directory, relative to the share root.
  /// - Returns: A `FileAllInformation` value containing extended attribute and stream data.
  /// - Throws: An error if the path does not exist or information cannot be retrieved.
  public func fileInfo(path: String) async throws -> FileAllInformation {
    let response = try await session.queryInfo(path: Pathname.normalize(path))
    return FileAllInformation(data: response.buffer)
  }

  /// Downloads the entire contents of a remote file and returns it as `Data`.
  ///
  /// - Parameter path: The path of the remote file, relative to the share root.
  /// - Returns: The complete contents of the file.
  /// - Throws: An error if the file cannot be opened or read.
  public func download(path: String) async throws -> Data {
    return try await download(path: path, progressHandler: { _ in })
  }

  /// Downloads the entire contents of a remote file, reporting progress, and returns it as `Data`.
  ///
  /// - Parameters:
  ///   - path: The path of the remote file, relative to the share root.
  ///   - progressHandler: A closure called periodically with the download progress as a value
  ///     between `0.0` (not started) and `1.0` (complete).
  /// - Returns: The complete contents of the file.
  /// - Throws: An error if the file cannot be opened or read.
  public func download(path: String, progressHandler: (_ progress: Double) -> Void) async throws -> Data {
    let fileReader = fileReader(path: Pathname.normalize(path))

    let data = try await fileReader.download(progressHandler: progressHandler)
    try await fileReader.close()

    return data
  }

  /// Downloads a remote file to a local URL on disk.
  ///
  /// - Parameters:
  ///   - path: The path of the remote file, relative to the share root.
  ///   - localPath: The local file URL to save the downloaded content to.
  ///   - overwrite: When `true`, an existing file at `localPath` is replaced.
  ///     Defaults to `false`.
  ///   - progressHandler: A closure called periodically with the download progress as a value
  ///     between `0.0` (not started) and `1.0` (complete). Defaults to a no-op closure.
  /// - Throws: An error if the remote file cannot be read or the local file cannot be written.
  public func download(path: String, localPath: URL, overwrite: Bool = false, progressHandler: (_ progress: Double) -> Void = { _ in }) async throws {
    let fileReader = fileReader(path: Pathname.normalize(path))
    
    try await fileReader.download(to: localPath, overwrite: overwrite, progressHandler: progressHandler)
    try await fileReader.close()
  }

  /// Uploads `Data` to a remote file path on the connected share.
  ///
  /// - Parameters:
  ///   - content: The data to upload.
  ///   - path: The destination path on the share, relative to the share root.
  /// - Throws: An error if the file cannot be created or written.
  public func upload(content: Data, path: String) async throws {
    try await upload(content: content, path: Pathname.normalize(path), progressHandler: { _ in })
  }

  /// Uploads `Data` to a remote file path, reporting progress.
  ///
  /// - Parameters:
  ///   - content: The data to upload.
  ///   - path: The destination path on the share, relative to the share root.
  ///   - progressHandler: A closure called periodically with the upload progress as a value
  ///     between `0.0` (not started) and `1.0` (complete).
  /// - Throws: An error if the file cannot be created or written.
  public func upload(content: Data, path: String, progressHandler: (_ progress: Double) -> Void) async throws {
    let fileWriter = fileWriter(path: Pathname.normalize(path))

    try await fileWriter.upload(data: content, progressHandler: progressHandler)
    try await fileWriter.close()
  }

  /// Uploads the contents of an open `FileHandle` to a remote path on the connected share.
  ///
  /// - Parameters:
  ///   - fileHandle: An open file handle whose contents will be uploaded.
  ///   - path: The destination path on the share, relative to the share root.
  /// - Throws: An error if the file cannot be created or written.
  public func upload(fileHandle: FileHandle, path: String) async throws {
    try await upload(fileHandle: fileHandle, path: path, progressHandler: { _ in })
  }

  /// Uploads the contents of an open `FileHandle` to a remote path, reporting progress.
  ///
  /// After uploading, the original file attributes (e.g. timestamps) from the local file
  /// handle are restored on the remote file.
  ///
  /// - Parameters:
  ///   - fileHandle: An open file handle whose contents will be uploaded.
  ///   - path: The destination path on the share, relative to the share root.
  ///   - progressHandler: A closure called periodically with the upload progress as a value
  ///     between `0.0` (not started) and `1.0` (complete).
  /// - Throws: An error if the file cannot be created or written.
  public func upload(fileHandle: FileHandle, path: String, progressHandler: (_ progress: Double) -> Void) async throws {
    let path = Pathname.normalize(path)
    let fileWriter = fileWriter(path: path)

    try await fileWriter.upload(fileHandle: fileHandle, progressHandler: progressHandler)
    try await fileWriter.close()

    await fileWriter.restoreFileAttributes(fileHandle, path)
  }

  /// Uploads a local file or directory to a remote path on the connected share.
  ///
  /// - Parameters:
  ///   - localPath: The URL of the local file or directory to upload.
  ///   - path: The destination path on the share, relative to the share root.
  /// - Throws: An error if the local file cannot be read or the remote file cannot be written.
  public func upload(localPath: URL, remotePath path: String) async throws {
    try await upload(localPath: localPath, remotePath: path, progressHandler: { _, _, _ in })
  }

  /// Uploads a local file or directory to a remote path, reporting per-file progress.
  ///
  /// - Parameters:
  ///   - localPath: The URL of the local file or directory to upload.
  ///   - path: The destination path on the share, relative to the share root.
  ///   - progressHandler: A closure called for each file transfer, providing the number of
  ///     completed files, the URL of the file currently being transferred, and the number
  ///     of bytes sent so far.
  /// - Throws: An error if the local file cannot be read or the remote file cannot be written.
  public func upload(
    localPath: URL,
    remotePath path: String,
    progressHandler: (_ completedFiles: Int, _ fileBeingTransferred: URL, _ bytesSent: Int64) -> Void
  ) async throws {
    let fileWriter = fileWriter(path: Pathname.normalize(path))

    try await fileWriter.upload(localPath: localPath, progressHandler: progressHandler)
    try await fileWriter.close()
  }

  /// Creates a ``FileReader`` for reading a remote file at the given path.
  ///
  /// Use this for fine-grained, streaming access to file content. The caller is responsible
  /// for closing the reader when finished.
  ///
  /// - Parameter path: The path of the remote file, relative to the share root.
  /// - Returns: A ``FileReader`` ready to read from the specified path.
  public func fileReader(path: String) -> FileReader {
    FileReader(session: session, path: Pathname.normalize(path))
  }

  /// Creates a ``FileWriter`` for writing to a remote file at the given path.
  ///
  /// Use this for fine-grained, streaming writes to a file. The caller is responsible
  /// for closing the writer when finished.
  ///
  /// - Parameter path: The path of the remote file, relative to the share root.
  /// - Returns: A ``FileWriter`` ready to write to the specified path.
  public func fileWriter(path: String) -> FileWriter {
    FileWriter(session: session, path: Pathname.normalize(path))
  }

  /// Creates a ``TreeAccessor`` scoped to the specified share.
  ///
  /// A `TreeAccessor` can be used to perform operations on a share that is different
  /// from the one currently connected via ``connectShare(_:)``.
  ///
  /// - Parameter share: The name of the share to access.
  /// - Returns: A ``TreeAccessor`` connected to the specified share.
  public func treeAccessor(share: String) -> TreeAccessor {
    session.treeAccessor(share: share)
  }

  /// Returns the number of bytes of available (free) space on the connected share's volume.
  ///
  /// - Returns: The number of available bytes on the volume.
  /// - Throws: An error if the file-system size information cannot be retrieved.
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

  /// Sends an SMB2 ECHO request to keep the connection alive and verify server responsiveness.
  ///
  /// - Returns: The server's echo response.
  /// - Throws: An error if the echo request fails or times out.
  public func keepAlive() async throws -> Echo.Response {
    try await session.echo()
  }
}

/// Represents a share advertised by an SMB server.
///
/// Instances of `Share` are returned by ``SMBClient/listShares()``.
public struct Share: Hashable {
  /// The name of the share as advertised by the server.
  public let name: String

  /// A human-readable description of the share provided by the server.
  public let comment: String

  /// The type of the share (disk, printer, IPC, etc.).
  public let type: ShareType

  /// A set of flags that describe the type of an SMB share.
  public struct ShareType: OptionSet, Hashable {
    /// The raw bitmask value from the SMB protocol.
    public let rawValue: UInt32

    /// Creates a share type from the given raw bitmask value.
    public init(rawValue: UInt32) {
      self.rawValue = rawValue
    }

    /// A standard disk-tree share (the default share type).
    public static let diskTree = ShareType([])
    /// A print-queue share.
    public static let printQueue = ShareType(rawValue: SType.printQueue)
    /// A device share.
    public static let device = ShareType(rawValue: SType.device)
    /// An interprocess-communication (IPC) share.
    public static let ipc = ShareType(rawValue: SType.ipc)
    /// A Cluster File System share.
    public static let clusterFS = ShareType(rawValue: SType.clusterFS)
    /// A Scale-Out File System (SOFS) cluster share.
    public static let clusterSOFS = ShareType(rawValue: SType.clusterSOFS)
    /// A Distributed File System (DFS) cluster share.
    public static let clusterDFS = ShareType(rawValue: SType.clusterDFS)
    /// A special hidden share (names ending in `$`).
    public static let special = ShareType(rawValue: SType.special)
    /// A temporary share that is not persisted across server restarts.
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

/// Represents a file or directory entry returned by a directory listing.
///
/// Instances of `File` are returned by ``SMBClient/listDirectory(path:pattern:)``.
public struct File: Hashable {
  /// The name of the file or directory.
  public let name: String

  /// The size of the file in bytes. For directories this value is typically `0`.
  public var size: UInt64 { fileStat.size }

  /// `true` if this entry represents a directory.
  public var isDirectory: Bool { fileStat.isDirectory }

  /// `true` if this entry has the hidden attribute set.
  public var isHidden: Bool { fileStat.isHidden }

  /// `true` if this entry has the read-only attribute set.
  public var isReadOnly: Bool { fileStat.isReadOnly }

  /// `true` if this entry has the system attribute set.
  public var isSystem: Bool { fileStat.isSystem }

  /// `true` if this entry has the archive attribute set.
  public var isArchive: Bool { fileStat.isArchive }

  /// The date and time the file was created.
  public var creationTime: Date { fileStat.creationTime }

  /// The date and time the file was last accessed.
  public var lastAccessTime: Date { fileStat.lastAccessTime }

  /// The date and time the file was last modified.
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

/// A lightweight snapshot of a file or directory's attributes on an SMB share.
///
/// `FileStat` is returned by ``SMBClient/fileStat(path:)`` and is also embedded
/// in each ``File`` entry from a directory listing.
public struct FileStat: Hashable {
  /// The size of the file in bytes.
  public let size: UInt64

  /// `true` if the item is a directory.
  public let isDirectory: Bool

  /// `true` if the item has the hidden attribute set.
  public let isHidden: Bool

  /// `true` if the item has the read-only attribute set.
  public let isReadOnly: Bool

  /// `true` if the item has the system attribute set.
  public let isSystem: Bool

  /// `true` if the item has the archive attribute set.
  public let isArchive: Bool

  /// The date and time the item was created.
  public let creationTime: Date

  /// The date and time the item was last accessed.
  public let lastAccessTime: Date

  /// The date and time the item was last modified.
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
