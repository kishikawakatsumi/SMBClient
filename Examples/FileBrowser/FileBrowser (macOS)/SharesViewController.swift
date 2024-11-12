import Cocoa

private let storyboardID = "SharesViewController"

class SharesViewController: NSViewController {
  @IBOutlet private var outlineView: NSOutlineView!
  @IBOutlet private var pathBarView: PathBarView!
  @IBOutlet private var statusBarView: StatusBarView!

  private let serverNode: ServerNode
  private var tree: Tree<ShareNode>

  private var tabGroupObserving: NSKeyValueObservation?
  private var scrollViewObserving: NSKeyValueObservation?

  static func instantiate(serverNode: ServerNode, shares: Tree<ShareNode>) -> Self {
    let storyboard = NSStoryboard(name: storyboardID, bundle: nil)
    return storyboard.instantiateController(identifier: storyboardID) { (coder) in
      Self(coder: coder, serverNode: serverNode, shares: shares)
    }
  }

  required init?(coder: NSCoder) {
    return nil
  }

  required init?(coder: NSCoder, serverNode: ServerNode, shares: Tree<ShareNode>) {
    self.serverNode = serverNode
    self.tree = shares
    super.init(coder: coder)
  }

  deinit {
    tabGroupObserving?.invalidate()
    scrollViewObserving?.invalidate()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    title = serverNode.name

    outlineView.dataSource = self
    outlineView.delegate = self

    outlineView.doubleAction = #selector(doubleAction(_:))

    for column in outlineView.tableColumns {
      column.sortDescriptorPrototype = NSSortDescriptor(key: column.identifier.rawValue, ascending: true)
    }
    outlineView.sortDescriptors = outlineView.tableColumns.compactMap { $0.sortDescriptorPrototype }

    let pathControl = pathBarView.pathControl
    pathControl.url = URL(string: serverNode.name)
    for pathItem in pathControl.pathItems {
      pathItem.image = Icons.server
    }

    statusBarView.label.stringValue = NSLocalizedString("\(tree.rootNodes().count) items", comment: "")
  }

  override func viewDidAppear() {
    super.viewDidAppear()

    if let window = view.window, let tabGroup = view.window?.tabGroup, let outlineView {
      window.representedURL = URL(string: "smb:///\(serverNode.name))")
      window.standardWindowButton(.documentIconButton)?.image = Icons.server

      let serverNode = self.serverNode
      var tree = self.tree

      tabGroupObserving?.invalidate()
      tabGroupObserving = tabGroup.observe(\.selectedWindow) { (tabGroup, change) in
        if window == tabGroup.selectedWindow {
          guard let shares: [ShareNode] = DataRepository.shared.nodes(serverNode.path) else { return }
          tree.nodes.removeAll()
          tree.nodes.append(contentsOf: shares)
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

  @objc
  func doubleAction(_ sender: NSOutlineView) {
    let row = outlineView.clickedRow
    let rootNodes = tree.rootNodes()
    guard row >= 0 && row < rootNodes.count else { return }

    let shareNode = rootNodes[row]

    guard let navigationController = parent as? NavigationController else { return }

    let server = serverNode.name
    guard let session = SessionManager.shared.session(for: serverNode.id) else { return }

    Task { @MainActor in
      let treeAccessor = session.client.treeAccessor(share: shareNode.name)

      let filesViewController = FilesViewController.instantiate(
        accessor: treeAccessor,
        serverNode: serverNode,
        share: shareNode.name,
        path: "",
        rootPath: "/\(server)/\(shareNode.name)"
      )
      filesViewController.title = shareNode.name

      navigationController.push(filesViewController)
    }
  }
}

extension SharesViewController: NSOutlineViewDataSource {
  func outlineView(_ outlineView: NSOutlineView, numberOfChildrenOfItem item: Any?) -> Int {
    if let node = item as? ShareNode {
      if tree.hasChildren(node) {
        return tree.children(of: node).count
      } else {
        return 0
      }
    } else {
      return tree.rootNodes().count
    }
  }

  func outlineView(_ outlineView: NSOutlineView, child index: Int, ofItem item: Any?) -> Any {
    if let node = item as? ShareNode {
      return tree.children(of: node)[index]
    } else {
      return tree.rootNodes()[index]
    }
  }

  func outlineView(_ outlineView: NSOutlineView, isItemExpandable item: Any) -> Bool {
    false
  }

  func outlineView(_ outlineView: NSOutlineView, sortDescriptorsDidChange oldDescriptors: [NSSortDescriptor]) {
    guard let descriptor = outlineView.sortDescriptors.first else {
      return
    }

    switch descriptor.key {
    case "NameColumn":
      tree.nodes = tree.nodes
        .sorted { $0.name.localizedStandardCompare($1.name) == (descriptor.ascending ? .orderedAscending : .orderedDescending) }
      outlineView.reloadData()
    default:
      break
    }
  }
}

extension SharesViewController: NSOutlineViewDelegate {
  func outlineView(_ outlineView: NSOutlineView, viewFor tableColumn: NSTableColumn?, item: Any) -> NSView? {
    guard let column = tableColumn?.identifier else { return nil }
    guard let shareNode = item as? ShareNode else { return nil }

    switch column.rawValue {
    case "NameColumn":
      let cellIdentifier = NSUserInterfaceItemIdentifier("NameCell")
      guard let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView else { return nil }

      cell.imageView?.image = Icons.share
      cell.textField?.stringValue = shareNode.name

      return cell
    case "DateColumn":
      let cellIdentifier = NSUserInterfaceItemIdentifier("DateCell")
      guard let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView else { return nil }

      cell.textField?.stringValue = "--"

      return cell
    case "SizeColumn":
      let cellIdentifier = NSUserInterfaceItemIdentifier("SizeCell")
      guard let cell = outlineView.makeView(withIdentifier: cellIdentifier, owner: nil) as? NSTableCellView else { return nil }

      cell.textField?.stringValue = "--"

      return cell
    default:
      return nil
    }
  }
}
