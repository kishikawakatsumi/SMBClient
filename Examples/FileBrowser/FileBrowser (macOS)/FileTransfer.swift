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
            FileUploadUserInfoKey.share: treeAccessor.share ?? "",
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
