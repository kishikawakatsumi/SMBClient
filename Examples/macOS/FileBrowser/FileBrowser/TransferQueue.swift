import Foundation
import SMBClient

class TransferQueue {
  static let shared = TransferQueue()

  static let didAddTransfer = Notification.Name("TransferQueueDidAddTransfer")
  static let progressDidChange = Notification.Name("TransferQueueProgressDidChange")

  private(set) var transfers = [TransferInfo]()
  private let taskQueue = TaskQueue()

  private init() {}

  func addFileTransfer(_ fileTransfer: FileTransfer) {
    let throttler = Throttler(interval: 0.5)
    
    let index = transfers.count
    let name = fileTransfer.displayName

    transfers.append(TransferInfo(name: name, state: .queued))

    NotificationCenter.default.post(
      name: TransferQueue.didAddTransfer,
      object: self,
      userInfo: [TransferQueueUserInfoKey.index: index]
    )

    Task {
      var fileTransfer = fileTransfer
      fileTransfer.progressHandler = { (state) in
        Task {
          await throttler.throttle {
            await MainActor.run {
              self.transfers[index] = TransferInfo(name: name, state: state)
              
              NotificationCenter.default.post(
                name: TransferQueue.progressDidChange,
                object: self,
                userInfo: [TransferQueueUserInfoKey.context: TransferContext(index: index, name: name, state: state)]
              )
            }
          }
        }
      }

      await taskQueue.append(fileTransfer)
    }
  }

  private actor TaskQueue {
    var queue = [FileTransfer]()
    var current: FileTransfer?

    func append(_ fileTransfer: FileTransfer) {
      queue.append(fileTransfer)
      Task {
        await next()
      }
    }

    private func next() async {
      if let _ = current {
        return
      }
      if queue.isEmpty {
        return
      }

      let fileTransfer = queue.removeFirst()
      current = fileTransfer
      await fileTransfer.start()

      current = nil
      await next()
    }
  }
}

struct TransferInfo {
  let name: String
  let state: TransferState
}

struct TransferContext {
  let index: Int
  let name: String
  let state: TransferState
}

struct TransferQueueUserInfoKey: Hashable, Equatable, RawRepresentable {
  let rawValue: String

  init(rawValue: String) {
    self.rawValue = rawValue
  }
}

extension TransferQueueUserInfoKey {
  static let index = WindowControllerUserInfoKey(rawValue: "index")
  static let context = WindowControllerUserInfoKey(rawValue: "context")
}

private actor Throttler {
  private let interval: TimeInterval

  private var lastExecutionTime: Date?
  private var isScheduled = false
  private var lastAction: (() async -> Void)?

  init(interval: TimeInterval) {
    self.interval = interval
  }

  func throttle(action: @escaping () async -> Void) {
    lastAction = action
    let now = Date()

    if let lastExecutionTime = lastExecutionTime, now.timeIntervalSince(lastExecutionTime) < interval {
      if !isScheduled {
        isScheduled = true
        let delay = interval - now.timeIntervalSince(lastExecutionTime)
        Task {
          try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
          execute()
        }
      }
    } else {
      execute()
    }
  }

  private func execute() {
    lastExecutionTime = Date()
    isScheduled = false
    if let action = lastAction {
      Task {
        await action()
      }
    }
  }
}
