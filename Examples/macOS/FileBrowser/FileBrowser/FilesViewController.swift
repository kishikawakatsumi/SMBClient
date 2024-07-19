import Cocoa
import UniformTypeIdentifiers
import SMBClient

class FilesViewController: NSViewController {
  static let didStartActivities = Notification.Name("FilesViewControllerDidStartActivities")

  @IBOutlet private var outlineView: NSOutlineView!
  @IBOutlet private var pathBarView: PathBarView!
  @IBOutlet private var statusBarView: StatusBarView!

  let client: SMBClient
  let serverNode: ServerNode
  let share: String
  let path: String
  let rootPath: String

  private lazy var dirTree = DirectoryStructure(server: serverNode.path, path: path, client: client)

  private var nameFields = [NSTextField: String]()

  private var tabGroupObserving: NSKeyValueObservation?
  private var scrollViewObserving: NSKeyValueObservation?

  private let semaphore = Semaphore(value: 1)

  private var dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short
    return dateFormatter
  }()

  static func instantiate(client: SMBClient, serverNode: ServerNode, share: String, path: String, rootPath: String) -> Self {
    let storyboard = NSStoryboard(name: "FilesViewController", bundle: nil)
    return storyboard.instantiateController(identifier: "FilesViewController") { (coder) in
      Self(coder: coder, client: client, serverNode: serverNode, share: share, path: path, rootPath: rootPath)
    }
  }

  required init?(coder: NSCoder) {
    return nil
  }

  required init?(coder: NSCoder, client: SMBClient, serverNode: ServerNode, share: String, path: String, rootPath: String) {
    self.client = client
    self.serverNode = serverNode
    self.share = share
    self.path = path
    self.rootPath = rootPath
    super.init(coder: coder)
  }

  deinit {
    tabGroupObserving?.invalidate()
    scrollViewObserving?.invalidate()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    outlineView.dataSource = self
    outlineView.delegate = self

    outlineView.doubleAction = #selector(doubleAction(_:))
    outlineView.registerForDraggedTypes([.fileURL])

    for column in outlineView.tableColumns {
      column.sortDescriptorPrototype = NSSortDescriptor(key: column.identifier.rawValue, ascending: true)
    }
    outlineView.sortDescriptors = outlineView.tableColumns.compactMap { $0.sortDescriptorPrototype }

    let pathControl = pathBarView.pathControl
    pathControl.url = URL(string: join(rootPath, path)) 
    pathControl.action = #selector(pathControlClicked(_:))
    
    pathControl.pathItems.first?.image = Icons.server
    for pathItem in pathControl.pathItems.dropFirst(){
      pathItem.image = NSImage(named: NSImage.folderName)
    }

    dirTree.update(outlineView)
    updateItemCount()

    Task { @MainActor in
      do {
        if client.share != share {
          if let _ = client.share {
            try await client.disconnectShare()
          }
          try await client.connectShare(share)
        }

        await dirTree.reload()
        outlineView.reloadData()

        updateItemCount()
      } catch {
        NSAlert(error: error).runModal()
      }
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(searchTextDidChange(_:)),
      name: WindowController.searchTextDidChange,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(fileUploadDidFinish(_:)),
      name: FileUpload.didFinish,
      object: nil
    )
  }

  override func viewDidAppear() {
    super.viewDidAppear()

    if let window = view.window, let tabGroup = view.window?.tabGroup, let outlineView {
      let dirTree = self.dirTree

      tabGroupObserving?.invalidate()
      tabGroupObserving = tabGroup.observe(\.selectedWindow) { (tabGroup, change) in
        if window == tabGroup.selectedWindow {
          dirTree.update(outlineView)
          outlineView.reloadData()
        }
      }
    }
    if let outlineView {
      outlineView.enclosingScrollView?.automaticallyAdjustsContentInsets = false

      scrollViewObserving?.invalidate()
      scrollViewObserving = outlineView.enclosingScrollView?.observe(\.safeAreaInsets, options: [.initial]) { (scrollView, change) in
        let safeAreaInsets = scrollView.safeAreaInsets
        scrollView.contentInsets = NSEdgeInsets(top: safeAreaInsets.top, left: 0, bottom: 28 + 28, right: 0)
      }
    }
  }

  private func navigationController() -> NavigationController? {
    parent as? NavigationController
  }

  private func updateItemCount() {
    statusBarView.label.stringValue = NSLocalizedString("\(outlineView.numberOfRows) items", comment: "")
  }

  @objc
  private func searchTextDidChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo else {
      return
    }
    guard let searchText = userInfo[WindowControllerUserInfoKey.searchText] as? String else {
      return
    }
    guard navigationController()?.topViewController == self else {
      return
    }

    dirTree.filter(searchText)
    outlineView.reloadData()

    updateItemCount()
  }

  @objc
  private func fileUploadDidFinish(_ notification: Notification) {
    guard let userInfo = notification.userInfo else {
      return
    }
    guard let effectPath = userInfo[FileUploadUserInfoKey.path] as? String else {
      return
    }
    guard view.window == view.window?.tabGroup?.selectedWindow else {
      return
    }
    guard self == navigationController()?.topViewController else {
      return
    }

    let dirname = dirname(effectPath)
    Task {
      await dirTree.reload(directory: dirname, outlineView)
    }
  }

  @IBAction func openMenuAction(_ sender: Any?) {
    guard let fileNode = outlineView.item(atRow: outlineView.selectedRow) as? FileNode else { return }
    openFileNode(fileNode)
  }

  @objc
  private func doubleAction(_ sender: NSOutlineView) {
    openContextMenuAction(sender)
  }

  @IBAction
  private func openContextMenuAction(_ sender: Any) {
    let targetRows = outlineView.targetRows()

    guard let targetRow = targetRows.first else { return }
    guard let fileNode = outlineView.item(atRow: targetRow) as? FileNode else { return }

    openFileNode(fileNode)
  }

  private func openFileNode(_ fileNode: FileNode) {
    if fileNode.isDirectory {
      guard let navigationController = navigationController() else { return }

      let client = self.client
      let path = dirTree.resolvePath(fileNode)
      let rootPath = self.rootPath

      let filesViewController = FilesViewController.instantiate(
        client: client, serverNode: serverNode, share: share, path: path, rootPath: rootPath
      )
      filesViewController.title = fileNode.name

      navigationController.push(filesViewController)
    } else {
      let client = self.client
      let path = dirTree.resolvePath(fileNode)

      let windowController: NSWindowController

      if path.hasSuffix(".mov") || path.hasSuffix(".mp4") {
        windowController = VideoPlayerWindowController.instantiate(path: path, client: client)
        windowController.showWindow(nil)
      } else {
        windowController = DocumentWindowController.instantiate(path: path, client: client)
        windowController.showWindow(nil)
      }
    }
  }

  @IBAction func renameMenuAction(_ sender: Any?) {
    guard outlineView.selectedRow >= 0 else { return }
    beginEditing(outlineView.selectedRow)
  }

  @IBAction
  private func renameContextMenuAction(_ sender: Any) {
    guard outlineView.clickedRow >= 0 else { return }
    beginEditing(outlineView.clickedRow)
  }

  private func beginEditing(_ row: Int) {
    guard let _ = outlineView.item(atRow: row) as? FileNode else { return }

    guard let rowView = outlineView.rowView(atRow: row, makeIfNecessary: false) else { return }
    guard let cellView = rowView.view(atColumn: 0) as? NSTableCellView else { return }

    cellView.window?.makeFirstResponder(cellView.textField)
  }

  @IBAction func deleteMenuAction(_ sender: Any?) {
    Task {
      guard outlineView.selectedRow >= 0 else { return }
      await deleteFileNodes(rows: [outlineView.selectedRow])
    }
  }

  @IBAction
  private func deleteFileContextMenuAction(_ sender: Any) {
    Task {
      let targetRows = outlineView.targetRows()
      await deleteFileNodes(rows: targetRows)
    }
  }

  private func deleteFileNodes(rows: IndexSet) async {
    var reloadPaths = Set<String>()
    do {
      for row in rows {
        guard let fileNode = outlineView.item(atRow: row) as? FileNode else { continue }
        let path = fileNode.path

        if fileNode.isDirectory {
          try await client.deleteDirectory(path: path)
        } else {
          try await client.deleteFile(path: path)
        }

        reloadPaths.insert(dirname(path))
      }

      for reloadPath in reloadPaths {
        await dirTree.reload(directory: reloadPath, outlineView)
      }
    } catch {
      NSAlert(error: error).runModal()
    }
  }

  @objc
  private func pathControlClicked(_ sender: NSPathControl) {
    guard let pathItem = pathBarView.pathControl.clickedPathItem else { return }
    guard let navigationController = navigationController() else { return }
    guard let absolutePath = pathItem.url?.path else { return }

    let client = self.client
    let rootPath = self.rootPath

    if absolutePath.hasPrefix(rootPath) {
      let startIndex = absolutePath.index(absolutePath.startIndex, offsetBy: rootPath.count)
      let relativePath = String(absolutePath[startIndex...].dropFirst())
      guard relativePath != path else { return }

      let filesViewController = FilesViewController.instantiate(
        client: client, serverNode: serverNode, share: share, path: relativePath, rootPath: rootPath
      )
      filesViewController.title = pathItem.title

      navigationController.push(filesViewController)
    } else {
      guard let shares = DataRepository.shared.nodes(serverNode.path) else { return }
      let sharesViewController = SharesViewController.instantiate(
        serverNode: serverNode, shares: Tree(nodes: shares)
      )
      navigationController.push(sharesViewController)
    }
  }
}

extension FilesViewController: NSOutlineViewDataSource {
  func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    dirTree.numberOfChildren(of: item)
  }

  func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    dirTree.child(index: index, of: item)
  }

  func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
    dirTree.isItemExpandable(item)
  }

  // MARK: - Sorting

  func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
    guard let descriptor = outlineView.sortDescriptors.first else { return }

    dirTree.sort(descriptor)
    outlineView.reloadData()
  }

  // MARK: - Drag & Drop

  func outlineView(_ outlineView: NSOutlineView, pasteboardWriterForItem item: Any) -> (any NSPasteboardWriting)? {
    guard let fileNode = item as? FileNode else { return nil }

    let pasteboardItem = NSPasteboardItem()
    pasteboardItem.setString(fileNode.id.rawValue, forType: .fileURL)

    return pasteboardItem
  }

  func outlineView(_ outlineView: NSOutlineView, validateDrop info: any NSDraggingInfo, proposedItem item: Any?, proposedChildIndex index: Int) -> NSDragOperation {
    guard index == NSOutlineViewDropOnItemIndex else { return [] }
    guard let item else {
      if let _ = info.draggingSource as? NSOutlineView {
        return .move
      } else {
        return .copy
      }
    }
    guard let fileNode = item as? FileNode else { return [] }

    if let _ = info.draggingSource as? NSOutlineView {
      if !fileNode.isDirectory {
        if let parent = dirTree.parent(of: fileNode) {
          outlineView.setDropItem(parent, dropChildIndex: index)
        } else {
          outlineView.setDropItem(nil, dropChildIndex: NSOutlineViewDropOnItemIndex)
        }
      }
      return .move
    } else {
      if !fileNode.isDirectory {
        if let parent = dirTree.parent(of: fileNode) {
          outlineView.setDropItem(parent, dropChildIndex: index)
        } else {
          outlineView.setDropItem(nil, dropChildIndex: NSOutlineViewDropOnItemIndex)
        }
      }
      return .copy
    }
  }

  func outlineView(_ outlineView: NSOutlineView, acceptDrop info: any NSDraggingInfo, item: Any?, childIndex index: Int) -> Bool {
    guard let fileURLs = info.draggingPasteboard.readObjects(forClasses: [NSURL.self]) else { return false }

    if let _ = info.draggingSource as? NSOutlineView {
      func validate() -> Bool {
        for fileURL in fileURLs {
          guard let fileURL = fileURL as? URL else { return false }

          guard let node = dirTree.node(fileURL) else {
            return false
          }

          if let fileNode = item as? FileNode {
            guard fileNode.isDirectory else {
              return false
            }
            if dirTree.parent(of: node) == fileNode {
              return false
            }

            return true
          } else {
            if node.isRoot {
              return false
            }
            return true
          }
        }
        return false
      }

      if validate() {
        for fileURL in fileURLs {
          guard let fileURL = fileURL as? URL else { return false }

          guard let node = dirTree.node(fileURL) else {
            return false
          }

          if let fileNode = item as? FileNode {
            guard fileNode.isDirectory else {
              return false
            }
            if dirTree.parent(of: node) == fileNode {
              return false
            }

            Task {
              let basename = URL(fileURLWithPath: node.path).lastPathComponent
              let from = node.path
              let to = join(fileNode.path, basename)

              await moveFile(from: from, to: to)
            }
            continue
          } else {
            if node.isRoot {
              return false
            }

            Task {
              let basename = URL(fileURLWithPath: node.path).lastPathComponent
              let from = node.path
              let to = join(path, basename)

              await moveFile(from: from, to: to)
            }
            continue
          }
        }

        return true

        func moveFile(from: String, to: String) async {
          do {
            try await client.move(from: from, to: to)

            await dirTree.reload(directory: dirname(from), outlineView)
            await dirTree.reload(directory: dirname(to), outlineView)
          } catch {
            NSAlert(error: error).runModal()
          }
        }
      } else {
        return false
      }
    } else {
      for fileURL in fileURLs {
        guard let fileURL = fileURL as? URL else { return false }
        let queue = TransferQueue.shared

        let basename = fileURL.lastPathComponent
        if let fileNode = item as? FileNode {
          let destination = join(path, fileNode.name, basename)
          queue.addFileTransfer(
            FileUpload(source: fileURL, destination: destination, client: client)
          )
        } else {
          let destination = join(path, basename)
          queue.addFileTransfer(
            FileUpload(source: fileURL, destination: destination, client: client)
          )
        }
      }

      NotificationCenter.default.post(name: Self.didStartActivities, object: self)
      return true
    }
  }
}

extension FilesViewController: NSOutlineViewDelegate {
  func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
    guard let column = tableColumn?.identifier else { return nil }
    guard let fileNode = item as? FileNode else { return nil }

    switch column.rawValue {
    case "NameColumn":
      let cellIdentifier = NSUserInterfaceItemIdentifier("NameCell")
      guard let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView else { return nil }

      if fileNode.isDirectory {
        cell.imageView?.image = Icons.folder
      } else {
        if let type = UTType(tag: NSString(string: fileNode.name).pathExtension, tagClass: .filenameExtension, conformingTo: nil) {
          cell.imageView?.image = NSWorkspace.shared.icon(for: type)
        } else {
          cell.imageView?.image = Icons.file
        }
      }
      cell.textField?.stringValue = fileNode.name

      cell.textField?.delegate = self

      return cell
    case "DateColumn":
      let cellIdentifier = NSUserInterfaceItemIdentifier("DateCell")
      guard let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView else { return nil }

      if let fileNode = item as? FileNode {
        cell.textField?.stringValue = dateFormatter.string(from: fileNode.lastWriteTime)
      }

      return cell
    case "SizeColumn":
      let cellIdentifier = NSUserInterfaceItemIdentifier("SizeCell")
      guard let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView else { return nil }

      if let fileNode = item as? FileNode {
        if fileNode.isDirectory {
          cell.textField?.stringValue = "--"
        } else {
          let size = ByteCountFormatter.string(fromByteCount: Int64(fileNode.size), countStyle: .file)
          cell.textField?.stringValue = size
        }
      }

      return cell
    default:
      return nil
    }
  }

  func outlineViewItemWillExpand(_ notification: Notification) {
    guard let userInfo = notification.userInfo else { return }
    guard let fileNode = userInfo["NSObject"] as? FileNode else { return }
    guard fileNode.isDirectory else { return }

    Task { @MainActor in
      await semaphore.wait()
      defer { Task { await semaphore.signal() } }

      await dirTree.expand(fileNode, outlineView)
      updateItemCount()
    }
  }

  func outlineViewItemDidCollapse(_ notification: Notification) {
    updateItemCount()
  }
}

extension FilesViewController: NSMenuItemValidation {
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    switch menuItem.menu?.title {
    case "File":
      let selectedRows = outlineView.selectedRowIndexes

      switch menuItem.title {
      case "Open":
        guard selectedRows.count == 1 else { return false }
        guard let selectedRow = selectedRows.first else { return false }
        guard let _ = outlineView.item(atRow: selectedRow) as? FileNode else { return false }
        return true
      case "Delete":
        guard selectedRows.count > 0 else { return false }
        return selectedRows.allSatisfy { outlineView.item(atRow: $0) is FileNode }
      case "Rename":
        guard selectedRows.count == 1 else { return false }
        guard let selectedRow = selectedRows.first else { return false }
        guard let _ = outlineView.item(atRow: selectedRow) as? FileNode else { return false }
        return true
      default:
        return false
      }
    default:
      let targetRows = outlineView.targetRows()

      switch menuItem.title {
      case "Open":
        guard targetRows.count == 1 else { return false }
        guard let targetRow = targetRows.first else { return false }
        guard let _ = outlineView.item(atRow: targetRow) as? FileNode else { return false }
        return true
      case "Delete":
        guard targetRows.count > 0 else { return false }
        return targetRows.allSatisfy { outlineView.item(atRow: $0) is FileNode }
      case "Rename":
        guard targetRows.count == 1 else { return false }
        guard let targetRow = targetRows.first else { return false }
        guard let _ = outlineView.item(atRow: targetRow) as? FileNode else { return false }
        return true
      default:
        return false
      }
    }
  }
}

extension FilesViewController: NSTextFieldDelegate {
  func control(_ control: NSControl, textShouldBeginEditing fieldEditor: NSText) -> Bool {
    guard let textField = control as? NSTextField else {
      return true
    }
    if let _ = nameFields[textField] {
      return false
    }
    nameFields[textField] = textField.stringValue
    return true
  }

  func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
    guard let textField = control as? NSTextField else {
      return true
    }
    guard let original = nameFields[textField] else {
      nameFields[textField] = nil
      return true
    }
    guard !textField.stringValue.isEmpty else {
      textField.stringValue = original
      nameFields[textField] = nil
      return true
    }
    guard textField.stringValue != original else {
      nameFields[textField] = nil
      return true
    }

    Task { @MainActor in
      do {
        try await client.rename(from: join(path, original), to: join(path, textField.stringValue))
        nameFields[textField] = nil
      } catch {
        textField.stringValue = original
        NSAlert(error: error).runModal()
      }
    }

    return true
  }
}

func dirname(_ path: String) -> String {
  let dirname = URL(fileURLWithPath: path)
    .deletingLastPathComponent()
    .standardized
    .pathname

  return dirname.hasSuffix("/") ? String(dirname.dropLast()) : dirname
}

func join(_ paths: String...) -> String {
  guard let first = paths.first else { return "" }
  if first.isEmpty {
    return paths.dropFirst().joined(separator: "/")
  } else {
    return paths.joined(separator: "/")
  }
}
