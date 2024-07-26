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
    switch item {
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
          await SidebarManager.shared.logoff(serverNode)
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
    guard let item = sourceList.item(atRow: sourceList.selectedRow) as? Node else { return }

    let sidebarManager = SidebarManager.shared
    let sessionManager = SessionManager.shared

    let node = sidebarManager.selectRow(item)

    switch node {
    case let serverNode as ServerNode:
      guard let _ = sessionManager.session(for: serverNode.id) else { return }

      Task { @MainActor in
        await sidebarManager.updateChildren(of: serverNode)

        sourceList.reloadItem(serverNode, reloadChildren: true)
        sourceList.expandItem(serverNode)

        let row = sourceList.row(forItem: serverNode)
        if let rowView = sourceList.rowView(atRow: row, makeIfNecessary: false) {
          rowView.isSelected = true
        }

        guard let navigationController = navigationController() else { return }

        guard let shares = DataRepository.shared.nodes(serverNode.path) else { return }
        let sharesViewController = SharesViewController.instantiate(serverNode: serverNode, shares: Tree(nodes: shares))
        navigationController.push(sharesViewController)
      }
    case let shareNode as ShareNode:
      guard let serverNode = sidebarManager.parent(of: shareNode) as? ServerNode else { return }
      guard let session = sessionManager.session(for: serverNode.id) else { return }

      Task { @MainActor in
        do {
          let client = session.client
          _ = try await client.treeConnect(path: shareNode.name)

          let filesViewController = FilesViewController.instantiate(
            client: client,
            serverNode: serverNode,
            share: shareNode.name,
            path: "",
            rootPath: "/\(shareNode.device)/\(shareNode.name)"
          )
          filesViewController.title = shareNode.name

          navigationController()?.push(filesViewController)
        } catch {
          NSAlert(error: error).runModal()
        }
      }
    default:
      sourceList.deselectRow(sourceList.selectedRow)
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
    switch menuItem.menu?.title {
    case "File":
      return false
    default:
      let clickedRow = sourceList.clickedRow
      guard let serverNode = sourceList.item(atRow: clickedRow) as? ServerNode else { return false }

      let servers = ServerManager.shared.servers
      return servers.contains { $0.id == serverNode.id }
    }
  }
}
