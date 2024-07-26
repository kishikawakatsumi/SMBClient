import Cocoa

class WindowController: NSWindowController {
  static let searchTextDidChange = Notification.Name("WindowControllerSearchTextDidChange")

  private let segmentedControl = NSSegmentedControl()

  private let activitiesViewController = ActivitiesViewController.instantiate()
  private let popover = NSPopover()

  private var searchField: NSSearchField?

  override func windowDidLoad() {
    super.windowDidLoad()

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
    guard let navigationController = navigationController() else {
      return
    }

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
  private func navigationDidFinished(_ notification: Notification) {
    guard let navigationController = navigationController() else {
      return
    }

    segmentedControl.setEnabled(navigationController.canGoBack(), forSegment: 0)
    segmentedControl.setEnabled(navigationController.canGoForward(), forSegment: 1)

    window?.title = navigationController.currentViewController().title ?? ""
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
      guard let itemViewer = sender.value(forKey: "_itemViewer") as? NSView else {
        return
      }
      popover.show(relativeTo: itemViewer.bounds, of: itemViewer, preferredEdge: .minY)
    }
  }

  @objc
  private func didStartActivities(_ notification: Notification) {
    guard let toolbarItems = window?.toolbar?.items else {
      return
    }
    guard let toolbarItem = toolbarItems.first(where: { $0.itemIdentifier == .activitiesToolbarItemIdentifer }) else {
      return
    }

    activitiesAction(toolbarItem)
  }

  @IBAction
  private func findAction(_ sender: Any) {
    window?.makeFirstResponder(searchField)
  }
}

extension WindowController: NSToolbarDelegate {
  func toolbarDefaultItemIdentifiers(_ toolbar: NSToolbar) -> [NSToolbarItem.Identifier] {
    [
      .navigationToolbarItemIdentifer,
      .connectToServerToolbarItemIdentifer,
      .activitiesToolbarItemIdentifer,
      .searchToolbarItemIdentifer,
    ]
  }

  func toolbar(
    _ toolbar: NSToolbar,
    itemForItemIdentifier itemIdentifier: NSToolbarItem.Identifier,
    willBeInsertedIntoToolbar flag: Bool
  ) -> NSToolbarItem? {
    switch itemIdentifier {
    case .navigationToolbarItemIdentifer:
      let group = NSToolbarItemGroup(itemIdentifier: itemIdentifier)

      let back = NSToolbarItem(itemIdentifier: .backToolbarItemIdentifer)
      back.label = "Back"

      let forward = NSToolbarItem(itemIdentifier: .forwardItemIdentifer)
      forward.label = "Forward"

      segmentedControl.segmentStyle = .separated
      segmentedControl.trackingMode = .momentary
      segmentedControl.segmentCount = 2

      segmentedControl.setImage(NSImage(systemSymbolName: "chevron.left", accessibilityDescription: nil)!, forSegment: 0)
      segmentedControl.setWidth(32, forSegment: 0)

      segmentedControl.setImage(NSImage(systemSymbolName: "chevron.right", accessibilityDescription: nil)!, forSegment: 1)
      segmentedControl.setWidth(32, forSegment: 1)

      segmentedControl.action = #selector(WindowController.navigationAction(_:))

      segmentedControl.setEnabled(false, forSegment: 0)
      segmentedControl.setEnabled(false, forSegment: 1)

      group.label = "Back/Forward"
      group.paletteLabel = "Navigation"
      group.subitems = [back, forward]
      group.isNavigational = true
      group.view = segmentedControl

      return group
    case .connectToServerToolbarItemIdentifer:
      let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)

      toolbarItem.isBordered = true
      toolbarItem.image = NSImage(named: "server.rack.badge.plus")
      toolbarItem.label = NSLocalizedString("Connect", comment: "")
      toolbarItem.action = #selector(connectToServerAction(_:))

      return toolbarItem

    case .activitiesToolbarItemIdentifer:
      let toolbarItem = NSToolbarItem(itemIdentifier: itemIdentifier)

      toolbarItem.isBordered = true
      toolbarItem.image = NSImage(systemSymbolName: "arrow.up.arrow.down.circle", accessibilityDescription: nil)
      toolbarItem.label = NSLocalizedString("Activities", comment: "")
      toolbarItem.action = #selector(activitiesAction(_:))

      return toolbarItem
    case .searchToolbarItemIdentifer:
      let toolbarItem = NSSearchToolbarItem(itemIdentifier: itemIdentifier)
      toolbarItem.searchField.delegate = self
      searchField = toolbarItem.searchField
      return toolbarItem
    default:
      return nil
    }
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
  static let navigationToolbarItemIdentifer = NSToolbarItem.Identifier("NavigationToolbarItem")
  static let backToolbarItemIdentifer = NSToolbarItem.Identifier("BackToolbarItem")
  static let forwardItemIdentifer = NSToolbarItem.Identifier("ForwardToolbarItem")

  static let connectToServerToolbarItemIdentifer = NSToolbarItem.Identifier("ConnectToServerToolbarItem")
  static let activitiesToolbarItemIdentifer = NSToolbarItem.Identifier("ActivitiesToolbbarItem")
  static let searchToolbarItemIdentifer = NSToolbarItem.Identifier("SearchToolbarItem")
}
