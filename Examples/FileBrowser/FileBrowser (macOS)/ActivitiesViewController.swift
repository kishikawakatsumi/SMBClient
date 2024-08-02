import Cocoa

class ActivitiesViewController: NSViewController {
  @IBOutlet private var tableView: NSTableView!

  static func instantiate() -> Self {
    let storyboard = NSStoryboard(name: "Activities", bundle: nil)
    return storyboard.instantiateInitialController() as! Self
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    tableView.dataSource = self
    tableView.delegate = self

    tableView.rowHeight = 54

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didAddTransfer(_:)),
      name: TransferQueue.didAddTransfer,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(progressDidChange(_:)),
      name: TransferQueue.progressDidChange,
      object: nil
    )
  }

  @objc
  private func didAddTransfer(_ notification: Notification) {
    guard let userInfo = notification.userInfo else { return }
    guard let index = userInfo[TransferQueueUserInfoKey.index] as? Int else { return }

    let reversedIndex = tableView.numberOfRows - 1 - index
    tableView.insertRows(at: [reversedIndex])

    tableView.reloadData()
  }

  @objc
  private func progressDidChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo else { return }
    guard let context = userInfo[TransferQueueUserInfoKey.context] as? TransferContext else { return }
    guard context.index < tableView.numberOfRows else { return }

    let reversedIndex = tableView.numberOfRows - 1 - context.index
    tableView.reloadData(forRowIndexes: [reversedIndex], columnIndexes: [0])
  }

  @IBAction
  private func clearActivities(_ sender: NSSegmentedControl) {
    let deleted = TransferQueue.shared.clearFinishedTransfers()

    for index in deleted {
      tableView.removeRows(at: [tableView.numberOfRows - 1 - index])
    }
  }
}

extension ActivitiesViewController: NSTableViewDataSource {
  func numberOfRows(in tableView: NSTableView) -> Int {
    let transferQueue = TransferQueue.shared
    return transferQueue.transfers.count
  }
}

extension ActivitiesViewController: NSTableViewDelegate {
  func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
    let cellIdentifier = NSUserInterfaceItemIdentifier("ActivityCell")
    guard let cell = tableView.makeView(withIdentifier: cellIdentifier, owner: nil) as? ActivityCell else { return nil }

    let transferQueue = TransferQueue.shared
    let reversedIndex = tableView.numberOfRows - 1 - row
    let transfer = transferQueue.transfers[reversedIndex]

    switch transfer.state {
    case .queued:
      cell.imageView?.image = Icons.file
      cell.textField?.stringValue = transfer.name
      cell.progressIndicator.isHidden = true
      cell.messageLabel.stringValue = NSLocalizedString("Queued", comment: "")
    case .started(let progress):
      switch progress {
      case .file(let progress, let numberOfBytes):
        cell.imageView?.image = Icons.file
        cell.textField?.stringValue = transfer.name

        cell.progressIndicator.isHidden = false
        cell.progressIndicator.isIndeterminate = false
        cell.progressIndicator.doubleValue = progress

        let progressBytes = ByteCountFormatter.string(fromByteCount: Int64(Double(numberOfBytes) * progress), countStyle: .file)
        let totalBytes = ByteCountFormatter.string(fromByteCount: numberOfBytes, countStyle: .file)
        let message = NSLocalizedString("\(progressBytes) of \(totalBytes)", comment: "")
        cell.messageLabel.stringValue = message
      case .directory(let completedFiles, let fileBeingTransferred, _):
        cell.imageView?.image = Icons.folder

        if let fileBeingTransferred {
          cell.textField?.stringValue = NSLocalizedString("\(fileBeingTransferred.lastPathComponent) in \(transfer.name)", comment: "")
        } else {
          cell.textField?.stringValue = transfer.name
        }

        cell.progressIndicator.isHidden = false
        cell.progressIndicator.isIndeterminate = true
        cell.progressIndicator.startAnimation(nil)

        let message = NSLocalizedString("\(completedFiles) files uploaded", comment: "")
        cell.messageLabel.stringValue = message
      }
    case .completed(let progress):
      switch progress {
      case .file(_, let numberOfBytes):
        cell.imageView?.image = Icons.file
        cell.textField?.stringValue = transfer.name
        cell.progressIndicator.isHidden = true

        let message = ByteCountFormatter.string(fromByteCount: numberOfBytes, countStyle: .file)
        cell.messageLabel.stringValue = message
      case .directory(_, _, let bytesSent):
        cell.imageView?.image = Icons.folder

        cell.textField?.stringValue = transfer.name
        cell.progressIndicator.isHidden = true

        let message = ByteCountFormatter.string(fromByteCount: bytesSent, countStyle: .file)
        cell.messageLabel.stringValue = message
      }
    case .failed(let error):
      cell.imageView?.image = Icons.file
      cell.textField?.stringValue = transfer.name
      cell.progressIndicator.isHidden = true
      cell.messageLabel.stringValue = error.localizedDescription
    }

    return cell
  }
}
