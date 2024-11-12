import Cocoa

@main
class AppDelegate: NSObject, NSApplicationDelegate {
  private var windowControllers = [NSWindowController]()

  func applicationDidFinishLaunching(_ aNotification: Notification) {
    ServiceDiscovery.shared.start()
    ServerManager.shared.restoreSavedServers()

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(windowWillClose(_:)),
      name: NSWindow.willCloseNotification,
      object: nil
    )
  }

  func applicationSupportsSecureRestorableState(_ app: NSApplication) -> Bool {
    return true
  }

  func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
    guard !flag else { return false}
    guard let window = sender.windows.first else { return false }

    window.makeKeyAndOrderFront(nil)
    return true
  }

  @IBAction
  private func newWindowForTab(_ sender: Any?) {
    guard let windowController = NSStoryboard(name: "Main", bundle: nil).instantiateInitialController() as? WindowController else {
      return
    }
    guard let newWindow = windowController.window else {
      return
    }

    guard let contentViewController = windowController.contentViewController as? SplitViewController else {
      return
    }
    let splitViewItems = contentViewController.splitViewItems
    guard let sidebarViewController = splitViewItems[0].viewController as? SidebarViewController else {
      return
    }
    guard let sourceList = sidebarViewController.sourceList else {
      return
    }
    guard let navigationController = splitViewItems[1].viewController as? NavigationController else {
      return
    }

    guard let existWindow = NSApp.mainWindow else {
      return
    }
    guard let existWindowController = existWindow.delegate as? WindowController else {
      return
    }
    guard let existViewController = existWindowController.contentViewController as? SplitViewController else {
      return
    }
    let existSplitViewItems = existViewController.splitViewItems
    guard let existSidebarViewController = existSplitViewItems[0].viewController as? SidebarViewController else {
      return
    }
    guard let existSourceList = existSidebarViewController.sourceList else {
      return
    }
    guard let existNavigationController = existSplitViewItems[1].viewController as? NavigationController else {
      return
    }

    for row in 0..<existSourceList.numberOfRows {
      guard let item = sourceList.item(atRow: row) else {
        continue
      }
      if existSourceList.isItemExpanded(item) {
        sourceList.expandItem(item)
      }
    }

    if let foregroundViewController = existNavigationController.topViewController as? FilesViewController {
      for row in 0..<existSourceList.numberOfRows {
        if let mainRowView = existSourceList.rowView(atRow: row, makeIfNecessary: false) {
          if let rowView = sourceList.rowView(atRow: row, makeIfNecessary: false) {
            rowView.isSelected = mainRowView.isSelected
          }
        }
      }

      let filesViewController = FilesViewController.instantiate(
        accessor: foregroundViewController.treeAccessor,
        serverNode: foregroundViewController.serverNode,
        share: foregroundViewController.share,
        path: foregroundViewController.path,
        rootPath: foregroundViewController.rootPath
      )
      filesViewController.title = foregroundViewController.title

      navigationController.push(filesViewController)
    } else {
      sourceList.selectRowIndexes([existSourceList.selectedRow], byExtendingSelection: false)
    }

    existWindow.addTabbedWindow(newWindow, ordered: .above)
    newWindow.makeKeyAndOrderFront(nil)

    windowControllers.append(windowController)
  }

  @objc
  private func windowWillClose(_ notification: Notification) {
    guard let window = notification.object as? NSWindow else { return }
    guard let index = windowControllers.firstIndex(where: { $0.window == window }) else { return }
    windowControllers.remove(at: index)
  }
}
