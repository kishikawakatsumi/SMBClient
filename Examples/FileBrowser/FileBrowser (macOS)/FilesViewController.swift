import Cocoa
import UniformTypeIdentifiers
import AVKit
import Quartz
import SMBClient

class FilesViewController: NSViewController {
  static let didStartActivities = Notification.Name("FilesViewControllerDidStartActivities")

  @IBOutlet private var outlineView: NSOutlineView!
  @IBOutlet private var pathBarView: PathBarView!
  @IBOutlet private var statusBarView: StatusBarView!

  let treeAccessor: TreeAccessor
  let serverNode: ServerNode
  let share: String
  let path: String
  let rootPath: String

  private lazy var dirTree = DirectoryStructure(server: serverNode.path, path: path, accessor: treeAccessor)
  private let semaphore = Semaphore(value: 1)

  private var tabGroupObserving: NSKeyValueObservation?
  private var scrollViewObserving: NSKeyValueObservation?

  private var availableSpace: UInt64?

  /// Cache of QuickLookItem objects keyed by SMB path. We need to keep them
  /// alive across `previewPanel(_:previewItemAt:)` calls so the temp file
  /// they back is stable, but they're built lazily from the live selection
  /// rather than snapshotted up front (which would go stale).
  private var quickLookItemCache: [String: QuickLookItem] = [:]

  // Video overlay laid on top of QLPreviewPanel.contentView. We reuse the
  // existing SMBAVAsset (AVAssetResourceLoaderDelegate-backed) so playback
  // streams from SMB without first downloading the file.
  private var quickLookPlayerView: AVPlayerView?
  private var quickLookCurrentAsset: SMBAVAsset?
  private var quickLookCurrentVideoPath: String?

  private var dateFormatter: DateFormatter = {
    let dateFormatter = DateFormatter()
    dateFormatter.dateStyle = .medium
    dateFormatter.timeStyle = .short
    return dateFormatter
  }()

  static func instantiate(accessor: TreeAccessor, serverNode: ServerNode, share: String, path: String, rootPath: String) -> Self {
    let storyboard = NSStoryboard(name: "FilesViewController", bundle: nil)
    return storyboard.instantiateController(identifier: "FilesViewController") { (coder) in
      Self(coder: coder, accessor: accessor, serverNode: serverNode, share: share, path: path, rootPath: rootPath)
    }
  }

  required init?(coder: NSCoder) {
    return nil
  }

  required init?(coder: NSCoder, accessor: TreeAccessor, serverNode: ServerNode, share: String, path: String, rootPath: String) {
    self.treeAccessor = accessor
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
    // Without these, NSOutlineView's drag source defaults to .none for
    // non-local sessions, which silently kills any drag-out to Finder no
    // matter what file-promise pasteboard data we write. .move enables the
    // existing within-outline rename/move; .copy enables the drag-out
    // download path.
    outlineView.setDraggingSourceOperationMask(.move, forLocal: true)
    outlineView.setDraggingSourceOperationMask(.copy, forLocal: false)

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
        try await dirTree.reload()
        outlineView.reloadData()

        availableSpace = try await dirTree.availableSpace()
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

    let keepAliveTimer = Timer(timeInterval: 300, repeats: true) { [weak self, treeAccessor, path] (timer) in
      guard let _ = self else {
        timer.invalidate()
        return
      }
      Task {
        do {
          _ = try await treeAccessor.fileInfo(path: path)
        } catch {
          timer.invalidate()
        }
      }
    }
    RunLoop.main.add(keepAliveTimer, forMode: .common)
  }

  override func viewDidAppear() {
    super.viewDidAppear()

    if let window = view.window, let tabGroup = view.window?.tabGroup, let outlineView {
      window.representedURL = URL(string: "smb:///\(join(rootPath, path))")
      if let type = UTType(tag: NSString(string: path).pathExtension, tagClass: .filenameExtension, conformingTo: nil) {
        window.standardWindowButton(.documentIconButton)?.image = Icons.icon(for: type)
      } else {
        window.standardWindowButton(.documentIconButton)?.image = Icons.folder
      }

      let dirTree = self.dirTree

      tabGroupObserving?.invalidate()
      tabGroupObserving = tabGroup.observe(\.selectedWindow) { [weak self] (tabGroup, change) in
        guard let self = self else { return }
        if window == tabGroup.selectedWindow {
          guard self == navigationController()?.topViewController else {
            return
          }
          dirTree.update(outlineView)
          self.updateItemCount()
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
    if let availableSpace {
      statusBarView.label.stringValue = NSLocalizedString("\(outlineView.numberOfRows) items, \(ByteCountFormatter.string(fromByteCount: Int64(availableSpace), countStyle: .file)) available", comment: "")
    } else {
      statusBarView.label.stringValue = NSLocalizedString("\(outlineView.numberOfRows) items", comment: "")
    }
  }

  @objc
  private func searchTextDidChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo else {
      return
    }
    guard let searchText = userInfo[WindowControllerUserInfoKey.searchText] as? String else {
      return
    }
    guard  let window = view.window, window == window.tabGroup?.selectedWindow else {
      return
    }
    guard self == navigationController()?.topViewController else {
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
    guard let share = userInfo[FileUploadUserInfoKey.share] as? String, share == self.share else {
      return
    }

    let dirname = dirname(effectPath)
    if let node = dirTree.node(ID(dirname)) {
      guard outlineView.isItemExpanded(node) else {
        return
      }
    } else {
      guard dirname == path else {
        return
      }
    }

    Task { @MainActor in
      do {
        try await dirTree.reload(directory: dirname, outlineView)
        updateItemCount()
      } catch {
        NSAlert(error: error).runModal()
      }
    }
  }

  func createNewFolder() {
    let filenames = dirTree
      .rootNodes()
      .map { $0.name }

    let filename = {
      let baseName = NSLocalizedString("untitled folder", comment: "")
      if !filenames.contains(baseName) {
        return baseName
      } else {
        var i = 2
        while true {
          let name = "\(baseName) \(i)"
          if !filenames.contains(name) {
            return name
          }
          i += 1
        }
      }
    }()
    Task {
      do {
        try await treeAccessor.createDirectory(path: join(path, filename))
        try await dirTree.reload(directory: path, outlineView)
        updateItemCount()
      } catch {
        NSAlert(error: error).runModal()
      }
    }
  }

  @IBAction func openMenuAction(_ sender: Any?) {
    guard let fileNode = outlineView.item(atRow: outlineView.selectedRow) as? FileNode else { return }
    openFileNode(fileNode)
  }

  // MARK: - Quick Look
  //
  // AppKit's spacebar is NOT auto-routed to `quickLook(with:)` (only F4 is).
  // Apple's QuickLookDownloader sample intercepts spacebar in its NSTableView
  // subclass and dispatches a toggle-the-preview-panel selector through the
  // responder chain. We do the same: `FilesOutlineView` calls
  // `NSApp.sendAction(#selector(NSResponder.quickLookPreviewItems(_:)), ...)`
  // which lands here. F4 still works through the standard
  // `quickLook(with:)` → `quickLookPreviewItems(_:)` chain on NSResponder.

  override func quickLookPreviewItems(_ sender: Any?) {
    guard let panel = QLPreviewPanel.shared() else { return }
    if panel.isVisible {
      panel.orderOut(nil)
    } else {
      panel.makeKeyAndOrderFront(nil)
      // Always force the panel to screen center on open. This sidesteps
      // AppKit's panel-position persistence — which otherwise drifts
      // whenever we resize the panel for a large video and have no
      // reliable way to put back.
      panel.center()
    }
  }

  override func acceptsPreviewPanelControl(_ panel: QLPreviewPanel!) -> Bool {
    true
  }

  override func beginPreviewPanelControl(_ panel: QLPreviewPanel!) {
    panel.dataSource = self
    panel.delegate = self
  }

  override func endPreviewPanelControl(_ panel: QLPreviewPanel!) {
    panel.dataSource = nil
    panel.delegate = nil
    removeQuickLookVideoOverlay()
    // Wipe per-session scratch files (each item has its own UUID-named
    // subdirectory; deleting that subdir takes the placeholder/downloaded
    // file with it).
    for item in quickLookItemCache.values {
      try? FileManager.default.removeItem(at: item.localURL.deletingLastPathComponent())
    }
    quickLookItemCache.removeAll()
  }

  // MARK: - Video overlay on QLPreviewPanel

  /// Returns true if `extension` is something AVFoundation can play.
  fileprivate static func isVideoExtension(_ ext: String) -> Bool {
    MediaPlayerWindowController.supportedExtensions.contains(ext.lowercased())
  }

  /// Lay (or update) an AVPlayerView on top of the panel's content view for the
  /// given video file node. If the player view already exists we just swap in
  /// the new AVPlayerItem; otherwise we install it once. For non-video items
  /// callers should call `removeQuickLookVideoOverlay()` instead so Apple's
  /// standard preview underneath becomes visible again.
  fileprivate func presentQuickLookVideoOverlay(for fileNode: FileNode, smbPath: String) {
    guard let panel = QLPreviewPanel.shared(),
          panel.isVisible,
          let containerView = panel.contentView
    else { return }

    // Same path is already streaming — nothing to do (avoids re-fetching the
    // first bytes when the data source happens to query the same item twice).
    if quickLookCurrentVideoPath == smbPath, quickLookPlayerView?.player != nil {
      return
    }

    if quickLookPlayerView == nil {
      let playerView = AVPlayerView(frame: containerView.bounds)
      playerView.autoresizingMask = [.width, .height]
      playerView.controlsStyle = .floating
      playerView.videoGravity = .resizeAspect
      playerView.wantsLayer = true
      playerView.layer?.backgroundColor = NSColor.black.cgColor
      containerView.addSubview(playerView, positioned: .above, relativeTo: nil)
      quickLookPlayerView = playerView
    }

    // Tear down previous asset before installing the new one. SMBAVAsset.close()
    // closes the underlying FileReader, so we don't leak SMB handles when
    // arrow-keying through a list of videos.
    let previousPlayer = quickLookPlayerView?.player
    quickLookPlayerView?.player = nil
    previousPlayer?.replaceCurrentItem(with: nil)
    quickLookCurrentAsset?.close()
    quickLookCurrentAsset = nil

    let asset = SMBAVAsset(accessor: treeAccessor, path: smbPath)
    quickLookCurrentAsset = asset
    quickLookCurrentVideoPath = smbPath

    let playerItem = AVPlayerItem(asset: asset)
    let player = AVPlayer(playerItem: playerItem)
    quickLookPlayerView?.player = player
    player.play()

    resizeQuickLookPanelToVideoSize(of: asset)
  }

  /// Resize the QLPreviewPanel to fit the video's natural dimensions, capped
  /// to 80% of the screen's visible frame and aspect-preserved. We do this
  /// asynchronously because reading `naturalSize` requires the asset's track
  /// metadata, which AVFoundation loads on-demand.
  private func resizeQuickLookPanelToVideoSize(of asset: SMBAVAsset) {
    Task { @MainActor [weak self, asset] in
      guard let self else { return }
      guard let track = try? await asset.loadTracks(withMediaType: .video).first else { return }
      guard let naturalSize = try? await track.load(.naturalSize),
            naturalSize.width > 0, naturalSize.height > 0 else { return }
      // Skip if the user has already navigated to another item.
      guard self.quickLookCurrentAsset === asset else { return }
      guard let panel = QLPreviewPanel.shared(), panel.isVisible else { return }

      // Match MediaPlayerWindowController: AVMakeRect inside the screen's
      // visibleFrame so the longer side stretches all the way to the menu
      // bar / Dock edges, then cap at naturalSize so small videos aren't
      // upscaled.
      guard let visibleFrame = (panel.screen ?? NSScreen.main)?.visibleFrame else { return }
      let fitted = AVMakeRect(aspectRatio: naturalSize, insideRect: visibleFrame)
      let contentSize = NSSize(
        width: min(fitted.width, naturalSize.width),
        height: min(fitted.height, naturalSize.height)
      )
      panel.setContentSize(contentSize)
      panel.center()
    }
  }

  fileprivate func removeQuickLookVideoOverlay() {
    if let player = quickLookPlayerView?.player {
      player.pause()
      player.replaceCurrentItem(with: nil)
    }
    quickLookPlayerView?.player = nil
    quickLookPlayerView?.removeFromSuperview()
    quickLookPlayerView = nil
    quickLookCurrentAsset?.close()
    quickLookCurrentAsset = nil
    quickLookCurrentVideoPath = nil
  }

  /// Rows currently selected, sorted by row index. Directories are included
  /// so Quick Look can show them with folder icon + metadata, mirroring
  /// Finder's behaviour.
  fileprivate func selectedNodesForQuickLook() -> [FileNode] {
    outlineView.selectedRowIndexes
      .sorted()
      .compactMap { outlineView.item(atRow: $0) as? FileNode }
  }

  /// Builds (or returns the cached) `QuickLookItem` for the given file node.
  ///
  /// We materialise something on the local disk for every item because
  /// `QLPreviewItem.previewItemURL` must point at a real `file://` URL:
  ///
  /// * **Directory** – an empty local directory is created. Quick Look then
  ///   falls back to its standard folder preview (folder icon + metadata),
  ///   matching what Finder shows for directories.
  /// * **Video** – an empty placeholder file is created with the original
  ///   extension. The AVPlayerView overlay covers Quick Look's rendering, so
  ///   the underlying QL preview never matters.
  /// * **Anything else** – an empty placeholder is created and a full
  ///   download kicks off in the background. When the bytes land we call
  ///   `refreshCurrentPreviewItem()` to swap to the real preview. If the
  ///   download fails or the type isn't previewable, Quick Look's generic
  ///   icon + metadata view is shown — again mirroring Finder.
  fileprivate func quickLookItem(for fileNode: FileNode) -> QuickLookItem {
    let smbPath = dirTree.resolvePath(fileNode)
    if let cached = quickLookItemCache[smbPath] { return cached }

    // Each item lives in its own subdirectory so the original filename (and
    // thus extension) is preserved verbatim — this is what Quick Look uses
    // to pick a preview generator.
    let scratchParent = QuickLookItem.scratchDirectory
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try? FileManager.default.createDirectory(
      at: scratchParent, withIntermediateDirectories: true
    )
    let localURL = scratchParent.appendingPathComponent(fileNode.name)

    let isVideo = !fileNode.isDirectory
      && Self.isVideoExtension((fileNode.name as NSString).pathExtension)
    let item: QuickLookItem

    if fileNode.isDirectory {
      try? FileManager.default.createDirectory(
        at: localURL, withIntermediateDirectories: true
      )
      item = QuickLookItem(title: fileNode.name, smbPath: smbPath, localURL: localURL)
    } else if isVideo {
      try? Data().write(to: localURL, options: .atomic)
      item = QuickLookItem(title: fileNode.name, smbPath: smbPath, localURL: localURL)
    } else {
      try? Data().write(to: localURL, options: .atomic)
      item = QuickLookItem(title: fileNode.name, smbPath: smbPath, localURL: localURL)
      startQuickLookDownload(for: item)
    }

    quickLookItemCache[smbPath] = item
    return item
  }

  /// Pulls the full content of an SMB file to the temp location backing
  /// `item.localURL` and asks Quick Look to re-render once the file is on
  /// disk. We only refresh the panel if the item is still the current one,
  /// since arrow-keying past it shouldn't yank the visible preview.
  private func startQuickLookDownload(for item: QuickLookItem) {
    Task { [weak self, treeAccessor, smbPath = item.smbPath, localURL = item.localURL, weak item] in
      do {
        let data = try await treeAccessor.download(path: smbPath)
        try data.write(to: localURL, options: .atomic)
        await MainActor.run {
          guard self != nil else { return }
          guard let panel = QLPreviewPanel.shared(), panel.isVisible else { return }
          if let current = panel.currentPreviewItem as? QuickLookItem,
             current === item {
            panel.refreshCurrentPreviewItem()
          }
        }
      } catch {
        // Download failed: leave the empty placeholder. Quick Look will
        // fall back to its generic icon + metadata preview, which is what
        // we want for un-previewable files anyway.
      }
    }
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
      let treeAccessor = self.treeAccessor
      let path = dirTree.resolvePath(fileNode)
      let rootPath = self.rootPath
      let serverNode = self.serverNode
      let share = self.share
      let title = fileNode.name

      let makeFilesViewController: () -> FilesViewController = {
        let vc = FilesViewController.instantiate(
          accessor: treeAccessor, serverNode: serverNode, share: share, path: path, rootPath: rootPath
        )
        vc.title = title
        return vc
      }

      // Cmd-click / Cmd-double-click on a directory opens it in a new tab,
      // matching Finder's gesture.
      let cmdHeld = NSApp.currentEvent?.modifierFlags.contains(.command) ?? false
      if cmdHeld {
        (NSApp.delegate as? AppDelegate)?.openInNewTab(adjacentTo: view.window) { nav in
          nav.push(makeFilesViewController())
        }
        return
      }

      guard let navigationController = navigationController() else { return }
      navigationController.push(makeFilesViewController())
    } else {
      let treeAccessor = self.treeAccessor
      let path = dirTree.resolvePath(fileNode)

      let windowController: NSWindowController

      let pathExtension = URL(fileURLWithPath: path).pathExtension
      if MediaPlayerWindowController.supportedExtensions.contains(pathExtension) {
        windowController = MediaPlayerWindowController.instantiate(path: path, accessor: treeAccessor)
        windowController.showWindow(nil)
      } else {
        windowController = DocumentWindowController.instantiate(accessor: treeAccessor, path: path)
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
    // Drive editing through the table-view entry point. The basename-only
    // initial selection is handled by `FilenameTextField` when it becomes
    // first responder; attempting to force the selection here gets
    // overwritten by AppKit's own select-all as the field editor attaches.
    outlineView.editColumn(0, row: row, with: nil, select: true)
  }

  @IBAction func deleteMenuAction(_ sender: Any?) {
    Task {
      guard outlineView.selectedRow >= 0 else { return }
      await deleteFileNodes(rows: [outlineView.selectedRow])
    }
  }

  @IBAction
  private func deleteFileContextMenuAction(_ sender: Any) {
    let targetRows = outlineView.targetRows()

    Task {
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
          try await treeAccessor.deleteDirectory(path: path)
        } else {
          try await treeAccessor.deleteFile(path: path)
        }

        reloadPaths.insert(dirname(path))
      }

      for reloadPath in reloadPaths {
        try await dirTree.reload(directory: reloadPath, outlineView)
      }
      updateItemCount()
    } catch {
      NSAlert(error: error).runModal()
    }
  }

  @objc
  private func pathControlClicked(_ sender: NSPathControl) {
    guard let pathItem = pathBarView.pathControl.clickedPathItem else { return }
    guard let navigationController = navigationController() else { return }
    guard let absolutePath = pathItem.url?.path else { return }

    let treeAccessor = self.treeAccessor
    let rootPath = self.rootPath

    if absolutePath.hasPrefix(rootPath) {
      let startIndex = absolutePath.index(absolutePath.startIndex, offsetBy: rootPath.count)
      let relativePath = String(absolutePath[startIndex...].dropFirst())
      guard relativePath != path else { return }

      let filesViewController = FilesViewController.instantiate(
        accessor: treeAccessor, serverNode: serverNode, share: share, path: relativePath, rootPath: rootPath
      )
      filesViewController.title = pathItem.title

      navigationController.push(filesViewController)
    } else {
      guard let shares: [ShareNode] = DataRepository.shared.nodes(serverNode.path) else { return }
      let sharesViewController = SharesViewController.instantiate(serverNode: serverNode, shares: Tree(nodes: shares))
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

    // Use NSFilePromiseProvider so dragging a row onto Finder triggers a
    // download. The custom `.smbeamSMBPath` type is written alongside the
    // file promise so internal drops within outlineView (= rename/move)
    // can still recover the SMB path. UTType picks the file's filename
    // extension so Finder's drop progress UI gets a sensible icon.
    let utiIdentifier: String
    if fileNode.isDirectory {
      utiIdentifier = UTType.folder.identifier
    } else {
      let ext = (fileNode.name as NSString).pathExtension
      utiIdentifier = UTType(filenameExtension: ext)?.identifier ?? UTType.data.identifier
    }
    let provider = SMBFilePromiseProvider(fileType: utiIdentifier, delegate: self)
    provider.userInfo = SMBPromiseInfo(smbPath: fileNode.path, isDirectory: fileNode.isDirectory)
    return provider
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
    if let _ = info.draggingSource as? NSOutlineView {
      // Internal drag — moves within the share. Source identity is now
      // carried on the custom `.smbeamSMBPath` pasteboard type written
      // alongside the file promise (see SMBFilePromiseProvider).
      let smbPaths: [String] = (info.draggingPasteboard.pasteboardItems ?? []).compactMap {
        $0.string(forType: .smbeamSMBPath)
      }
      let nodes: [FileNode] = smbPaths.compactMap { dirTree.node(ID($0)) }
      guard !nodes.isEmpty else { return false }

      func validate() -> Bool {
        for node in nodes {
          if let fileNode = item as? FileNode {
            guard fileNode.isDirectory else { return false }
            if dirTree.parent(of: node) == fileNode { return false }
            return true
          } else {
            if node.isRoot { return false }
            return true
          }
        }
        return false
      }

      if validate() {
        for node in nodes {
          if let fileNode = item as? FileNode {
            guard fileNode.isDirectory else { return false }
            if dirTree.parent(of: node) == fileNode { return false }

            Task {
              let basename = URL(fileURLWithPath: node.path).lastPathComponent
              let from = node.path
              let to = join(fileNode.path, basename)

              await moveFile(from: from, to: to)
            }
            continue
          } else {
            if node.isRoot { return false }

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
            try await treeAccessor.move(from: from, to: to)

            try await dirTree.reload(directory: dirname(from), outlineView)
            try await dirTree.reload(directory: dirname(to), outlineView)

            updateItemCount()
          } catch {
            NSAlert(error: error).runModal()
          }
        }
      } else {
        return false
      }
    } else {
      // External drag — Finder uploads. NSURLs are still on the pasteboard
      // because Finder writes them itself.
      guard let fileURLs = info.draggingPasteboard.readObjects(forClasses: [NSURL.self]) else { return false }
      for fileURL in fileURLs {
        guard let fileURL = fileURL as? URL else { return false }
        let queue = TransferQueue.shared

        func replaceUnavailableCharacters(_ s: String) -> String {
          var s = s
          let invalidCharacters = #""*/:<>?\|"#
          for invalidCharacter in invalidCharacters {
            s = s.replacingOccurrences(of: String(invalidCharacter), with: "")
          }
          return s
        }
        let basename = replaceUnavailableCharacters(fileURL.lastPathComponent)
        if let fileNode = item as? FileNode {
          let destination = join(fileNode.path, basename)
          queue.addFileTransfer(
            FileUpload(source: fileURL, destination: destination, accessor: treeAccessor)
          )
        } else {
          let destination = join(path, basename)
          queue.addFileTransfer(
            FileUpload(source: fileURL, destination: destination, accessor: treeAccessor)
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

      if let type = UTType(tag: NSString(string: fileNode.name).pathExtension, tagClass: .filenameExtension, conformingTo: nil) {
        cell.imageView?.image = Icons.icon(for: type)
      } else if fileNode.isDirectory {
        cell.imageView?.image = Icons.folder
      } else {
        cell.imageView?.image = Icons.file
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

    dirTree.useCache = true

    Task { @MainActor in
      dirTree.useCache = false

      await semaphore.wait()
      defer { Task { await semaphore.signal() } }

      do {
        try await dirTree.expand(fileNode, outlineView)
        updateItemCount()
      } catch {
        NSAlert(error: error).runModal()
      }
    }
  }

  func outlineViewItemDidExpand(_ notification: Notification) {
    updateItemCount()
  }

  func outlineViewItemWillCollapse(_ notification: Notification) {
    dirTree.useCache = true
  }

  func outlineViewItemDidCollapse(_ notification: Notification) {
    dirTree.useCache = false
    updateItemCount()
  }

  func outlineViewSelectionDidChange(_ notification: Notification) {
    // If our Quick Look panel is up (i.e., we are its data source), keep its
    // contents in sync with the outline view's selection. This handles both
    // arrow-key navigation (forwarded from the panel via previewPanel(_:handle:))
    // and direct mouse selection changes while the panel remains open.
    guard let panel = QLPreviewPanel.shared(), panel.isVisible else { return }
    guard panel.dataSource === (self as AnyObject) else { return }
    panel.reloadData()
  }
}

extension FilesViewController: NSMenuItemValidation {
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    let selectedRows = outlineView.selectedRowIndexes
    let targetRows = outlineView.targetRows()

    switch menuItem.action {
    case #selector(openMenuAction(_:)):
      guard selectedRows.count == 1 else { return false }
      guard let selectedRow = selectedRows.first else { return false }
      guard let _ = outlineView.item(atRow: selectedRow) as? FileNode else { return false }
      return true
    case #selector(deleteMenuAction(_:)):
      guard selectedRows.count > 0 else { return false }
      return selectedRows.allSatisfy { outlineView.item(atRow: $0) is FileNode }
    case #selector(renameMenuAction(_:)):
      guard selectedRows.count == 1 else { return false }
      guard let selectedRow = selectedRows.first else { return false }
      guard let _ = outlineView.item(atRow: selectedRow) as? FileNode else { return false }
      return true
    case #selector(openContextMenuAction(_:)):
      guard targetRows.count == 1 else { return false }
      guard let targetRow = targetRows.first else { return false }
      return outlineView.item(atRow: targetRow) is FileNode
    case #selector(deleteFileContextMenuAction(_:)):
      guard targetRows.count > 0 else { return false }
      return targetRows.allSatisfy { outlineView.item(atRow: $0) is FileNode }
    case #selector(renameContextMenuAction(_:)):
      guard targetRows.count == 1 else { return false }
      guard let targetRow = targetRows.first else { return false }
      guard let _ = outlineView.item(atRow: targetRow) as? FileNode else { return false }
      return true
    case #selector(quickLookPreviewItems(_:)):
      // Enable the standard Quick Look menu item whenever any FileNode
      // (file or directory) is selected — Finder allows Quick Look on
      // directories too, showing the folder icon + metadata.
      guard !selectedRows.isEmpty else { return false }
      return selectedRows.contains(where: { outlineView.item(atRow: $0) is FileNode })
    default:
      return false
    }
  }
}

extension FilesViewController: QLPreviewPanelDataSource, QLPreviewPanelDelegate {
  func numberOfPreviewItems(in panel: QLPreviewPanel!) -> Int {
    selectedNodesForQuickLook().count
  }

  func previewPanel(_ panel: QLPreviewPanel!, previewItemAt index: Int) -> QLPreviewItem! {
    let nodes = selectedNodesForQuickLook()
    guard index >= 0, index < nodes.count else { return nil }
    let node = nodes[index]

    // For videos, install/refresh the streaming AVPlayerView overlay over
    // whatever Quick Look is rendering. For everything else (directories
    // and non-video files alike) drop the overlay so the standard Quick
    // Look chrome shows through.
    let pathExtension = (node.name as NSString).pathExtension
    let isVideo = !node.isDirectory && Self.isVideoExtension(pathExtension)
    if isVideo {
      let smbPath = dirTree.resolvePath(node)
      presentQuickLookVideoOverlay(for: node, smbPath: smbPath)
    } else {
      removeQuickLookVideoOverlay()
    }
    return quickLookItem(for: node)
  }

  /// Re-route key events received by the QLPreviewPanel back to the source
  /// outline view. Without this, arrow keys inside the panel just beep because
  /// nothing along the panel's responder chain knows what to do with them.
  /// Mirrors the QuickLookDownloader Apple sample.
  func previewPanel(_ panel: QLPreviewPanel!, handle event: NSEvent!) -> Bool {
    if event.type == .keyDown {
      outlineView.keyDown(with: event)
      return true
    }
    return false
  }
}

/// QLPreviewItem backed by a local-disk URL. The URL is mutable so the
/// owner can swap in real downloaded contents (and call
/// `QLPreviewPanel.refreshCurrentPreviewItem()`) once a background download
/// completes — the placeholder pattern Apple's docs describe for remote
/// content. A shared scratch directory under the process temp dir hosts all
/// per-item subfolders.
final class QuickLookItem: NSObject, QLPreviewItem {
  let title: String
  let smbPath: String
  var localURL: URL

  static let scratchDirectory: URL = {
    let dir = FileManager.default.temporaryDirectory
      .appendingPathComponent("SMBeam-QuickLook", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir
  }()

  init(title: String, smbPath: String, localURL: URL) {
    self.title = title
    self.smbPath = smbPath
    self.localURL = localURL
  }

  var previewItemURL: URL! { localURL }
  var previewItemTitle: String! { title }
}

// MARK: - Drag-out (file promise)

extension FilesViewController: NSFilePromiseProviderDelegate {
  /// Returns the on-disk file name Finder should use for the dropped file.
  /// Finder appends "copy" / number suffixes if a file with that name
  /// already exists at the drop location, so we don't have to handle
  /// collisions ourselves.
  func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, fileNameForType fileType: String) -> String {
    if let info = filePromiseProvider.userInfo as? SMBPromiseInfo {
      return (info.smbPath as NSString).lastPathComponent
    }
    return "Untitled"
  }

  /// AppKit invokes this on the queue returned from `operationQueue(for:)`
  /// once the user drops on a destination. We delegate the actual byte
  /// streaming to a `FileDownload` queued through `TransferQueue` so the
  /// Activities panel reflects the work, while reporting completion back
  /// to AppKit so it can dismiss its drag-progress indicator.
  func filePromiseProvider(_ filePromiseProvider: NSFilePromiseProvider, writePromiseTo url: URL, completionHandler: @escaping (Error?) -> Void) {
    guard let info = filePromiseProvider.userInfo as? SMBPromiseInfo else {
      completionHandler(URLError(.badURL))
      return
    }

    let download = FileDownload(
      sourcePath: info.smbPath,
      isDirectory: info.isDirectory,
      destination: url,
      accessor: treeAccessor
    )

    // Pre-set a progressHandler that resolves Finder's file promise on
    // terminal state. TransferQueue.addFileTransfer chains our handler in
    // front of its own throttled UI handler, so both run.
    let lock = NSLock()
    var resolved = false
    download.progressHandler = { state in
      let outcome: Result<Void, Error>?
      switch state {
      case .completed: outcome = .success(())
      case .failed(let error): outcome = .failure(error)
      case .queued, .started: outcome = nil
      }
      guard let outcome else { return }
      lock.lock()
      if resolved { lock.unlock(); return }
      resolved = true
      lock.unlock()
      switch outcome {
      case .success: completionHandler(nil)
      case .failure(let error): completionHandler(error)
      }
    }

    Task { @MainActor in
      TransferQueue.shared.addFileTransfer(download)
      // Surface the Activities panel so the user sees progress, matching
      // the upload-on-drop behaviour.
      NotificationCenter.default.post(name: Self.didStartActivities, object: self)
    }
  }

  /// Serial queue used for AppKit's writePromiseTo callbacks. We don't
  /// actually do work here — the work happens in TransferQueue's actor —
  /// but AppKit requires a non-main queue so the call doesn't block UI.
  func operationQueue(for filePromiseProvider: NSFilePromiseProvider) -> OperationQueue {
    Self.filePromiseQueue
  }

  private static let filePromiseQueue: OperationQueue = {
    let queue = OperationQueue()
    queue.qualityOfService = .userInitiated
    queue.name = "com.kishikawakatsumi.smbeam.file-promise"
    return queue
  }()
}

extension FilesViewController: NSTextFieldDelegate {
  func control(_ control: NSControl, textShouldEndEditing fieldEditor: NSText) -> Bool {
    guard let textField = control as? NSTextField else {
      return true
    }

    let row = outlineView.row(for: control)
    guard let node = outlineView.item(atRow: row) as? FileNode else {
      return true
    }

    guard !textField.stringValue.isEmpty else {
      textField.stringValue = node.name
      return true
    }
    guard textField.stringValue != node.name else {
      return true
    }

    Task { @MainActor in
      do {
        try await treeAccessor.rename(from: node.path, to: join(dirname(node.path), textField.stringValue))
        try await dirTree.reload(directory: dirname(node.path), outlineView)
      } catch {
        textField.stringValue = node.name
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

/// NSTextField subclass that mimics Finder's "select basename, leave extension"
/// behaviour when entering edit mode. AppKit's auto-select-all happens *after*
/// `NSTextFieldDelegate.controlTextDidBeginEditing(_:)` and after a synchronous
/// `selectedRange = …` from `becomeFirstResponder()`, so the override has to
/// dispatch to the next runloop tick on the responder path. The mouse path
/// already has the field editor installed by the time `super.mouseDown` returns,
/// so we can update the selection synchronously there.
///
/// Reference: CotEditor's FilenameTextField
/// (https://github.com/coteditor/CotEditor — Apache 2.0).
class FilenameTextField: NSTextField {
  override func mouseDown(with event: NSEvent) {
    super.mouseDown(with: event)
    currentEditor()?.smbeam_selectFilenameStem()
  }

  override func becomeFirstResponder() -> Bool {
    guard super.becomeFirstResponder() else { return false }
    DispatchQueue.main.async { [weak self] in
      self?.currentEditor()?.smbeam_selectFilenameStem()
    }
    return true
  }
}

private extension NSText {
  /// Selects the filename stem (the portion preceding the trailing
  /// `.<ext>`). For names without a "real" extension — directories without
  /// dot-suffixes, dotfiles like `.gitignore`, names like `README` —
  /// the entire string is selected, matching Finder.
  func smbeam_selectFilenameStem() {
    let name = self.string as NSString
    let stem = (name.deletingPathExtension as NSString)
    let length = stem.length > 0 ? stem.length : name.length
    self.selectedRange = NSRange(location: 0, length: length)
  }
}
