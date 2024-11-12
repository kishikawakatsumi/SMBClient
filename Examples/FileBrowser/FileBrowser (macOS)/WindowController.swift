import Cocoa
import UniformTypeIdentifiers

class WindowController: NSWindowController {
  static let searchTextDidChange = Notification.Name("WindowControllerSearchTextDidChange")

  private let segmentedControl = NSSegmentedControl()
  private let backHistoryMenu = NSMenu()
  private let forwardHistoryMenu = NSMenu()

  private let activitiesViewController = ActivitiesViewController.instantiate()
  private let popover = NSPopover()

  private var searchField: NSSearchField?

  override func windowDidLoad() {
    super.windowDidLoad()

    if let fieldEditor = window?.fieldEditor(true, for: nil) as? NSTextView {
      _ = fieldEditor.layoutManager
    }

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(navigationDidFinished(_:)),
      name: NavigationController.navigationDidFinished,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(didStartActivities(_:)),
      name: FilesViewController.didStartActivities,
      object: nil
    )
  }

  private func navigationController() -> NavigationController? {
    guard let splitViewController = contentViewController as? SplitViewController else {
      return nil
    }

    let splitViewItem = splitViewController.splitViewItems[1]
    guard let navigationController = splitViewItem.viewController as? NavigationController else {
      return nil
    }

    return navigationController
  }

  @objc
  private func navigationAction(_ sender: NSSegmentedControl) {
    guard let navigationController = navigationController() else { return }

    switch sender.selectedSegment {
    case 0:
      navigationController.back()
    case 1:
      navigationController.forward()
    default:
      break
    }

    sender.setEnabled(navigationController.canGoBack(), forSegment: 0)
    sender.setEnabled(navigationController.canGoForward(), forSegment: 1)
  }

  @objc
  private func backHistoryAction(_ sender: NSMenuItem) {
    guard let navigationController = navigationController() else { return }

    if let index = backHistoryMenu.items.firstIndex(of: sender) {
      navigationController.back(count: index + 1)
    }
  }

  @objc
  private func forwardHistoryAction(_ sender: NSMenuItem) {
    guard let navigationController = navigationController() else { return }

    if let index = forwardHistoryMenu.items.firstIndex(of: sender) {
      navigationController.forward(count: index + 1)
    }
  }

  @objc
  private func navigationDidFinished(_ notification: Notification) {
    guard let navigationController = navigationController() else { return }

    backHistoryMenu.removeAllItems()
    for viewController in navigationController.backHistory {
      let menuItem = NSMenuItem()
      if let title = viewController.title {
        menuItem.title = title
      }
      if let filesViewController = viewController as? FilesViewController,
         let type = UTType(tag: NSString(string: filesViewController.path).pathExtension, tagClass: .filenameExtension, conformingTo: nil) {
        menuItem.image = Icons.icon(for: type)
      } else if let _ = viewController as? SharesViewController {
        menuItem.image = Icons.server
      } else {
        menuItem.image = Icons.folder
      }
      menuItem.image?.size = NSSize(width: 16, height: 16)
      menuItem.action = #selector(backHistoryAction(_:))
      backHistoryMenu.addItem(menuItem)
    }

    forwardHistoryMenu.removeAllItems()
    for viewController in navigationController.forwardHistory {
      let menuItem = NSMenuItem()
      if let title = viewController.title {
        menuItem.title = title
      }
      if let filesViewController = viewController as? FilesViewController,
         let type = UTType(tag: NSString(string: filesViewController.path).pathExtension, tagClass: .filenameExtension, conformingTo: nil) {
        menuItem.image = Icons.icon(for: type)
      } else if let _ = viewController as? SharesViewController {
        menuItem.image = Icons.server
      } else {
        menuItem.image = Icons.folder
      }
      menuItem.image?.size = NSSize(width: 16, height: 16)
      menuItem.action = #selector(forwardHistoryAction(_:))
      forwardHistoryMenu.addItem(menuItem)
    }

    segmentedControl.setEnabled(navigationController.canGoBack(), forSegment: 0)
    segmentedControl.setEnabled(navigationController.canGoForward(), forSegment: 1)

    window?.title = navigationController.currentViewController()?.title ?? ""
  }

  @objc
  private func documentProxyPathMenuAction(_ sender: NSMenuItem) {
    guard let navigationController = navigationController() else { return }
    guard let menuItems = sender.menu?.items else { return }
    guard menuItems.first != sender else { return }

    guard let topViewController = navigationController.topViewController as? FilesViewController else {
      return
    }

    let treeAccessor = topViewController.treeAccessor
    let serverNode = topViewController.serverNode
    let share = topViewController.share
    let rootPath = topViewController.rootPath

    var path = ""
    if menuItems.reversed().firstIndex(of: sender) == 1 {
      guard let shares: [ShareNode] = DataRepository.shared.nodes(serverNode.path) else { return }
      let sharesViewController = SharesViewController.instantiate(serverNode: serverNode, shares: Tree(nodes: shares))
      navigationController.push(sharesViewController)
      return
    } else if menuItems.reversed().firstIndex(of: sender) == 2 {
      path = ""
    } else {
      for menuItem in menuItems.reversed().dropFirst(3) {
        guard !menuItem.title.isEmpty else { continue }

        path += "\(menuItem.title)"
        if menuItem == sender {
          break
        }
        path += "/"
      }
    }

    let filesViewController = FilesViewController.instantiate(
      accessor: treeAccessor, serverNode: serverNode, share: share, path: path, rootPath: rootPath
    )
    filesViewController.title = sender.title

    navigationController.push(filesViewController)
  }


  @IBAction
  private func newFolderAction(_ sender: NSToolbarItem) {
    guard let navigationController = navigationController() else { return }
    guard let filesViewController = navigationController.topViewController as? FilesViewController else { return }

    filesViewController.createNewFolder()
  }

  @objc
  private func connectToServerAction(_ sender: NSToolbarItem) {
    let serverManager = ServerManager.shared
    serverManager.connectToNewServer()
  }

  @objc
  private func activitiesAction(_ sender: NSToolbarItem) {
    guard !popover.isShown else {
      guard #available(macOS 14.0, *) else {
        popover.close()
        return
      }
      return
    }

    popover.behavior = .semitransient
    popover.contentViewController = activitiesViewController

    if #available(macOS 14.0, *) {
      popover.show(relativeTo: sender)
    } else {
      guard let itemViewer = sender.value(forKey: "_itemViewer") as? NSView else { return }
      popover.show(relativeTo: itemViewer.bounds, of: itemViewer, preferredEdge: .minY)
    }
  }

  @objc
  private func didStartActivities(_ notification: Notification) {
    guard let toolbarItems = window?.toolbar?.items else {
      return
    }
    guard let toolbarItem = toolbarItems.first(where: { $0.itemIdentifier == .activitiesToolbarItemIdentifier }) else {
      return
    }

    activitiesAction(toolbarItem)
  }

  @IBAction
  private func findAction(_ sender: Any) {
    window?.makeFirstResponder(searchField)
  }
}

extension WindowController: NSWindowDelegate {
  func window(_ window: NSWindow, shouldPopUpDocumentPathMenu menu: NSMenu) -> Bool {
    for item in menu.items {
      if let type = UTType(tag: NSString(string: item.title).pathExtension, tagClass: .filenameExtension, conformingTo: nil) {
        item.image = Icons.icon(for: type)
      } else {
        item.image = Icons.folder
      }
      item.image?.size = NSSize(width: 16, height: 16)
      item.target = self
      item.action = #selector(documentProxyPathMenuAction(_:))
    }
    return true
  }
}

extension WindowController: NSMenuItemValidation {
  func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
    if menuItem.action == #selector(documentProxyPathMenuAction(_:)) {
      return true
    }
    if menuItem.action == #selector(backHistoryAction(_:)) {
      guard let navigationController = navigationController() else { return false }
      return navigationController.canGoBack()
    }
    if menuItem.action == #selector(forwardHistoryAction(_:)) {
      guard let navigationController = navigationController() else { return false }
      return navigationController.canGoForward()
    }
    if menuItem.action == #selector(newFolderAction(_:)) {
      guard let navigationController = navigationController() else { return false }
      return navigationController.topViewController is FilesViewController
    }
    return false
  }
}

extension WindowController: NSToolbarDelegate {
  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [
      .navigationToolbarItemIdentifier,
      .newFolderToolbarItemIdentifier,
      .connectToServerToolbarItemIdentifier,
      .activitiesToolbarItemIdentifier,
      .searchToolbarItemIdentifier,
    ]
  }

  func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    switch itemIdentifier {
    case .navigationToolbarItemIdentifier:
      let group = NSToolbarItemGroup(itemIdentifier: itemIdentifier)

      let back = NSToolbarItem(itemIdentifier: .backToolbarItemIdentifier)
      back.label = "Back"

      let forward = NSToolbarItem(itemIdentifier: .forwardItemIdentifier)
      forward.label = "Forward"

      segmentedControl.segmentStyle = .separated
      segmentedControl.trackingMode = .momentary
      segmentedControl.segmentCount = 2

      segmentedControl.setImage(NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil)!, forSegment: 0)
      segmentedControl.setWidth(32, forSegment: 0)

      segmentedControl.setImage(NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)!, forSegment: 1)
      segmentedControl.setWidth(32, forSegment: 1)

      segmentedControl.setMenu(backHistoryMenu, forSegment: 0)
      segmentedControl.setMenu(forwardHistoryMenu, forSegment: 1)

      segmentedControl.action = #selector(WindowController.navigationAction(_:))

      segmentedControl.setEnabled(false, forSegment: 0)
      segmentedControl.setEnabled(false, forSegment: 1)

      group.label = "Back/Forward"
      group.paletteLabel = "Navigation"
      group.subitems = [back, forward]
      group.isNavigational = true
      group.view = segmentedControl

      return group
    case .newFolderToolbarItemIdentifier:
      let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)

      toolbarItem.isBordered = true
      toolbarItem.image = NSImage(systemSymbolName: "folder.badge.plus", accessibilityDescription: nil)
      toolbarItem.label = NSLocalizedString("New Folder", comment: "")
      toolbarItem.action = #selector(newFolderAction(_:))

      return toolbarItem
    case .connectToServerToolbarItemIdentifier:
      let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)

      toolbarItem.isBordered = true
      toolbarItem.image = NSImage(named: "server.rack.badge.plus")
      toolbarItem.label = NSLocalizedString("Connect", comment: "")
      toolbarItem.action = #selector(connectToServerAction(_:))

      return toolbarItem
    case .activitiesToolbarItemIdentifier:
      let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)

      toolbarItem.isBordered = true
      toolbarItem.image = NSImage(systemSymbolName: "arrow.up.arrow.down.circle", accessibilityDescription: nil)
      toolbarItem.label = NSLocalizedString("Activities", comment: "")
      toolbarItem.action = #selector(activitiesAction(_:))

      return toolbarItem
    case .searchToolbarItemIdentifier:
      let toolbarItem = NSSearchToolbarItem(itemIdentifier: itemIdentifier)
      toolbarItem.searchField.delegate = self
      searchField = toolbarItem.searchField
      return toolbarItem
    default:
      return nil
    }
  }
}

extension WindowController: NSToolbarItemValidation {
  func validateToolbarItem(_ item: NSToolbarItem) -> Bool {
    guard let navigationController = navigationController() else { return false }

    if item.itemIdentifier == .newFolderToolbarItemIdentifier {
      return navigationController.topViewController is FilesViewController
    }

    return true
  }
}

extension WindowController: NSSearchFieldDelegate {
  @objc
  func controlTextDidChange(_ notification : Notification){
    guard let searchField = notification.object as? NSSearchField else {
      return
    }
    NotificationCenter.default.post(
      name: Self.searchTextDidChange,
      object: self,
      userInfo: [WindowControllerUserInfoKey.searchText: searchField.stringValue]
    )
  }
}

struct WindowControllerUserInfoKey: Hashable, Equatable, RawRepresentable {
  let rawValue: String

  init(rawValue: String) {
    self.rawValue = rawValue
  }
}

extension WindowControllerUserInfoKey {
  static let searchText = WindowControllerUserInfoKey(rawValue: "searchText")
}

private extension NSToolbarItem.Identifier {
  static let navigationToolbarItemIdentifier = NSToolbarItem.Identifier("NavigationToolbarItem")
  static let backToolbarItemIdentifier = NSToolbarItem.Identifier("BackToolbarItem")
  static let forwardItemIdentifier = NSToolbarItem.Identifier("ForwardToolbarItem")

  static let newFolderToolbarItemIdentifier = NSToolbarItem.Identifier("NewFolderToolbarItem")
  static let connectToServerToolbarItemIdentifier = NSToolbarItem.Identifier("ConnectToServerToolbarItem")
  static let activitiesToolbarItemIdentifier = NSToolbarItem.Identifier("ActivitiesToolbbarItem")
  static let searchToolbarItemIdentifier = NSToolbarItem.Identifier("SearchToolbarItem")
}
