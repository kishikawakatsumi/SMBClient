import AppKit
import Foundation
import SMBClient

protocol FileTransfer {
  var id: UUID { get }
  var displayName: String { get }
  var state: TransferState { get }
  var progressHandler: (_ state: TransferState) -> Void { get set }

  func start() async
}

enum TransferState {
  case queued
  case started(TransferProgress)
  case completed(TransferProgress)
  case failed(Error)
}

enum TransferProgress {
  case file(progress: Double, numberOfBytes: Int64)
  case directory(completedFiles: Int, fileBeingTransferred: URL?,  bytesSent: Int64)
}

class FileUpload: FileTransfer {
  static let didFinish = Notification.Name("FileUploadDidFinish")

  let displayName: String
  var state: TransferState
  var progressHandler: (_ state: TransferState) -> Void

  let id: UUID
  private let source: URL
  private let destination: String
  private let treeAccessor: TreeAccessor

  init(source: URL, destination: String, accessor: TreeAccessor) {
    id = UUID()
    self.source = source
    self.destination = destination
    treeAccessor = accessor

    displayName = source.lastPathComponent
    state = .queued
    progressHandler = { _ in }
  }

  func start() async {
    let fileManager = FileManager()
    var isDirectory: ObjCBool = false

    do {
      guard fileManager.fileExists(atPath: source.path, isDirectory: &isDirectory) else {
        throw URLError(.fileDoesNotExist)
      }

      var transferProgress: TransferProgress
      if isDirectory.boolValue {
        transferProgress = .directory(completedFiles: 0, fileBeingTransferred: nil, bytesSent: 0)
        state = .started(transferProgress)
        progressHandler(state)

        try await treeAccessor.upload(localPath: source, remotePath: destination) { (completedFiles, fileBeingTransferred, bytesSent) in
          transferProgress = .directory(completedFiles: completedFiles, fileBeingTransferred: fileBeingTransferred, bytesSent: bytesSent)
          state = .started(transferProgress)
          progressHandler(state)
        }
      } else {
        let fileManager = FileManager()
        let attributes = try fileManager.attributesOfItem(atPath: source.pathname)

        guard let fileSize = attributes[.size] as? Int64 else { throw URLError(.zeroByteResource) }
        let numberOfBytes = fileSize

        let fileHandle = try FileHandle(forReadingFrom: source)

        transferProgress = .file(progress: 0, numberOfBytes: numberOfBytes)
        state = .started(transferProgress)
        progressHandler(state)

        try await treeAccessor.upload(fileHandle: fileHandle, path: destination) { (progress) in
          transferProgress = .file(progress: progress, numberOfBytes: numberOfBytes)
          state = .started(.file(progress: progress, numberOfBytes: numberOfBytes))
          progressHandler(state)
        }
      }

      switch transferProgress {
      case .file(progress: _, numberOfBytes: let numberOfBytes):
        state = .completed(.file(progress: 1, numberOfBytes: numberOfBytes))
      case .directory(completedFiles: let completedFiles, fileBeingTransferred: _, bytesSent: let bytesSent):
        state = .completed(.directory(completedFiles: completedFiles, fileBeingTransferred: nil, bytesSent: bytesSent))
      }
      progressHandler(state)

      await MainActor.run {
        NotificationCenter.default.post(
          name: Self.didFinish,
          object: self,
          userInfo: [
            FileUploadUserInfoKey.share: treeAccessor.share,
            FileUploadUserInfoKey.path: destination,
          ]
        )
      }
    } catch {
      state = .failed(error)
      progressHandler(state)
    }
  }
}

struct FileUploadUserInfoKey: Hashable, Equatable, RawRepresentable {
  let rawValue: String

  init(rawValue: String) {
    self.rawValue = rawValue
  }
}

extension FileUploadUserInfoKey {
  static let share = FileUploadUserInfoKey(rawValue: "share")
  static let path = FileUploadUserInfoKey(rawValue: "path")
}

/// Mirror of `FileUpload` for the drag-out-to-Finder path. The actual byte
/// stream is performed through the same TransferQueue serial pipeline so
/// uploads and downloads share the Activities UI and don't trample each
/// other's SMB session.
class FileDownload: FileTransfer {
  let displayName: String
  var state: TransferState
  var progressHandler: (_ state: TransferState) -> Void

  let id: UUID
  private let sourcePath: String
  private let isDirectory: Bool
  private let destination: URL
  private let treeAccessor: TreeAccessor

  init(sourcePath: String, isDirectory: Bool, destination: URL, accessor: TreeAccessor) {
    id = UUID()
    self.sourcePath = sourcePath
    self.isDirectory = isDirectory
    self.destination = destination
    treeAccessor = accessor
    displayName = (sourcePath as NSString).lastPathComponent
    state = .queued
    progressHandler = { _ in }
  }

  func start() async {
    do {
      if isDirectory {
        try await downloadDirectory()
      } else {
        try await downloadFile()
      }
    } catch {
      state = .failed(error)
      progressHandler(state)
    }
  }

  private func downloadFile() async throws {
    let fileReader = try await treeAccessor.fileReader(path: sourcePath)
    let totalBytes = Int64(try await fileReader.fileSize)

    state = .started(.file(progress: 0, numberOfBytes: totalBytes))
    progressHandler(state)

    try await fileReader.download(to: destination, overwrite: true) { (progress) in
      state = .started(.file(progress: progress, numberOfBytes: totalBytes))
      progressHandler(state)
    }
    try await fileReader.close()

    state = .completed(.file(progress: 1, numberOfBytes: totalBytes))
    progressHandler(state)
  }

  private func downloadDirectory() async throws {
    try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

    var completed = 0
    var bytesSent: Int64 = 0

    state = .started(.directory(completedFiles: 0, fileBeingTransferred: nil, bytesSent: 0))
    progressHandler(state)

    func walk(remoteDir: String, localDir: URL) async throws {
      let entries = try await treeAccessor.listDirectory(path: remoteDir)
      for entry in entries where entry.name != "." && entry.name != ".." {
        let childRemote = remoteDir.isEmpty ? entry.name : "\(remoteDir)/\(entry.name)"
        let childLocal = localDir.appendingPathComponent(entry.name)

        if entry.isDirectory {
          try FileManager.default.createDirectory(
            at: childLocal, withIntermediateDirectories: true
          )
          try await walk(remoteDir: childRemote, localDir: childLocal)
        } else {
          state = .started(.directory(
            completedFiles: completed,
            fileBeingTransferred: childLocal,
            bytesSent: bytesSent
          ))
          progressHandler(state)

          let reader = try await treeAccessor.fileReader(path: childRemote)
          let size = Int64(try await reader.fileSize)
          try await reader.download(to: childLocal, overwrite: true)
          try await reader.close()
          completed += 1
          bytesSent += size

          state = .started(.directory(
            completedFiles: completed,
            fileBeingTransferred: nil,
            bytesSent: bytesSent
          ))
          progressHandler(state)
        }
      }
    }

    try await walk(remoteDir: sourcePath, localDir: destination)

    state = .completed(.directory(
      completedFiles: completed,
      fileBeingTransferred: nil,
      bytesSent: bytesSent
    ))
    progressHandler(state)
  }
}

/// NSFilePromiseProvider subclass that also writes the SMB path as a custom
/// pasteboard type so the existing internal-drag (file move) handler in
/// FilesViewController can keep recovering the source file from the
/// dragging pasteboard. External (Finder) drops still use the file-promise
/// machinery on the `delegate` to materialise the file.
final class SMBFilePromiseProvider: NSFilePromiseProvider {
  override func writableTypes(for pasteboard: NSPasteboard) -> [NSPasteboard.PasteboardType] {
    var types = super.writableTypes(for: pasteboard)
    types.append(.smbeamSMBPath)
    return types
  }

  override func pasteboardPropertyList(forType type: NSPasteboard.PasteboardType) -> Any? {
    if type == .smbeamSMBPath {
      if let info = userInfo as? SMBPromiseInfo {
        return info.smbPath
      }
    }
    return super.pasteboardPropertyList(forType: type)
  }
}

/// Strongly typed payload stashed on a `SMBFilePromiseProvider.userInfo`.
/// `userInfo` is `Any?` on the system class; using a concrete struct here
/// avoids `[String: Any]` plumbing on every read.
struct SMBPromiseInfo {
  let smbPath: String
  let isDirectory: Bool
}

extension NSPasteboard.PasteboardType {
  static let smbeamSMBPath = NSPasteboard.PasteboardType("com.kishikawakatsumi.smbeam.smb-path")
}
