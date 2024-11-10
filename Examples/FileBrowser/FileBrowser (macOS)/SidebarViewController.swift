import Cocoa

class SidebarViewController: NSViewController {
  @IBOutlet private(set) var sourceList: NSOutlineView!

  override func viewDidLoad() {
    super.viewDidLoad()

    sourceList.dataSource = self
    sourceList.delegate = self

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(sidebarDidUpdate(_:)),
      name: SidebarManager.sidebarDidUpdate,
      object: nil
    )
  }

  @objc
  private func sidebarDidUpdate(_ notification: Notification) {
    sourceList.reloadData()
  }

  @IBAction
  private func removeServerContextMenuAction(_ sender: Any) {
    let clickedRow = sourceList.clickedRow
    guard let serverNode = sourceList.item(atRow: clickedRow) as? ServerNode else { return }

    let serverManager = ServerManager.shared
    if let server = serverManager.server(for: serverNode.id) {
      serverManager.removeServer(server)
    }
  }

  private func navigationController() -> NavigationController? {
    guard let splitViewController = parent as? SplitViewController else {
      return nil
    }

    let splitViewItem = splitViewController.splitViewItems[1]
    guard let navigationController = splitViewItem.viewController as? NavigationController else {
      return nil
    }

    return navigationController
  }
}

extension SidebarViewController: NSOutlineViewDataSource {
  func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    SidebarManager.shared.numberOfChildrenOfItem(item)
  }

  func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    SidebarManager.shared.child(index, ofItem: item)
  }

  func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
    SidebarManager.shared.isItemExpandable(item)
  }
}

extension SidebarViewController: NSOutlineViewDelegate {
  func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
    guard let node = item as? SidebarNode else { return nil }

    switch node.content {
    case let headerNode as HeaderNode:
      let cellIdentifier = NSUserInterfaceItemIdentifier("HeaderCell")
      guard let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView else { return nil }

      cell.textField?.stringValue = headerNode.name

      return cell
    case let serverNode as ServerNode:
      let cellIdentifier = NSUserInterfaceItemIdentifier("DataCell")
      guard let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: nil) as? SidebarCellView else { return nil }

      cell.imageView?.image = NSImage(systemSymbolName: "server.rack", accessibilityDescription: nil)
      cell.textField?.stringValue = serverNode.name

      cell.ejectButton.isHidden = !SessionManager.shared.sessionExists(for: serverNode.id)
      cell.ejectAction = {
        cell.ejectButton.isEnabled = false
        
        Task { @MainActor in
          await SidebarManager.shared.logoff(node)
          cell.ejectButton.isEnabled = true
        }
      }

      return cell
    case let shareNode as ShareNode:
      let cellIdentifier = NSUserInterfaceItemIdentifier("DataCell")
      guard let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: nil) as? SidebarCellView else { return nil }

      cell.imageView?.image = NSImage(systemSymbolName: "externaldrive.connected.to.line.below", accessibilityDescription: nil)
      cell.textField?.stringValue = shareNode.name
      cell.ejectButton.isHidden = true

      return cell
    default:
      return nil
    }
  }

  func outlineView(_ outlineView: NSOutlineView, shouldSelectItem item: Any) -> Bool {
    SidebarManager.shared.isItemSelectable(item)
  }

  func outlineViewSelectionDidChange(_ notification: Notification) {
    guard let item = sourceList.item(atRow: sourceList.selectedRow) as? SidebarNode else { return }

    let sidebarManager = SidebarManager.shared
    let sessionManager = SessionManager.shared

    guard let node = sidebarManager.selectRow(item) else {
      sourceList.deselectRow(sourceList.selectedRow)
      return
    }

    switch node.content {
    case let serverNode as ServerNode:
      guard let _ = sessionManager.session(for: serverNode.id) else { return }

      Task { @MainActor in
        await sidebarManager.updateChildren(of: node)

        sourceList.reloadItem(item, reloadChildren: true)
        sourceList.expandItem(item)

        let row = sourceList.row(forItem: item)
        if let rowView = sourceList.rowView(atRow: row, makeIfNecessary: false) {
          rowView.isSelected = true
        }

        guard let navigationController = navigationController() else { return }

        guard let shares: [ShareNode] = DataRepository.shared.nodes(serverNode.path) else { return }
        let sharesViewController = SharesViewController.instantiate(serverNode: serverNode, shares: Tree(nodes: shares))
        navigationController.push(sharesViewController)
      }
    case let shareNode as ShareNode:
      guard let serverNode = sidebarManager.parent(of: node)?.content as? ServerNode else { return }
      guard let session = sessionManager.session(for: serverNode.id) else { return }

      Task { @MainActor in
        let treeAccessor = session.client.treeAccessor(share: shareNode.name)

        let filesViewController = FilesViewController.instantiate(
          accessor: treeAccessor,
          serverNode: serverNode,
          share: shareNode.name,
          path: "",
          rootPath: "/\(shareNode.device)/\(shareNode.name)"
        )
        filesViewController.title = shareNode.name

        navigationController()?.push(filesViewController)
      }
    default:
      break
    }
  }

  func outlineView(_ outlineView: NSOutlineView, shouldShowOutlineCellForItem item: Any) -> Bool {
    return false
  }

  func outlineView(_ outlineView: NSOutlineView, shouldCollapseItem item: Any) -> Bool {
    return false
  }
}

extension SidebarViewController: NSMenuItemValidation {
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    guard menuItem.action == #selector(removeServerContextMenuAction(_:)) else {
      return false
    }

    let clickedRow = sourceList.clickedRow
    guard let serverNode = sourceList.item(atRow: clickedRow) as? ServerNode else { return false }

    let servers = ServerManager.shared.servers
    return servers.contains { $0.id == serverNode.id }
  }
}
