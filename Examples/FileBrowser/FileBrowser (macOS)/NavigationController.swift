import Cocoa

class NavigationController: NSViewController {
  static let navigationDidFinished = Notification.Name("NavigationControllerNavigationDidFinished")

  var topViewController: NSViewController? {
    guard !history.isEmpty else { return nil }
    return history[current]
  }

  var backHistory: [NSViewController] {
    Array(history.prefix(current).reversed())
  }

  var forwardHistory: [NSViewController] {
    Array(history.suffix(from: current + 1))
  }

  private var history = [NSViewController]()

  private var current = -1 {
    didSet {
      NotificationCenter.default.post(name: Self.navigationDidFinished, object: self)
    }
  }

  override func swipe(with event: NSEvent) {
    if event.deltaX > 0 {
      back()
    }
    if event.deltaX < 0 {
      forward()
    }
  }

  func push(_ viewController: NSViewController) {
    if current < history.count - 1 {
      history.removeSubrange(current + 1..<history.count)
    }

    replace(viewController)

    history.append(viewController)
    current += 1
  }

  func back() {
    guard canGoBack() else { return }

    let viewController = history[current - 1]
    replace(viewController)

    current -= 1
  }

  func back(count: Int) {
    guard current - count >= 0 else { return }

    let viewController = history[current - count]
    replace(viewController)

    current -= count
  }

  func forward() {
    guard canGoForward() else { return }

    let viewController = history[current + 1]
    replace(viewController)

    current += 1
  }

  func forward(count: Int) {
    guard current + count < history.count else { return }

    let viewController = history[current + count]
    replace(viewController)

    current += count
  }

  func canGoBack() -> Bool {
    current > 0
  }

  func canGoForward() -> Bool {
    current < history.count - 1
  }

  func currentViewController() -> NSViewController? {
    guard !history.isEmpty else { return nil }
    return history[current]
  }

  private func replace(_ viewController: NSViewController) {
    for child in children {
      child.removeFromParent()
      child.view.removeFromSuperview()
    }

    viewController.view.frame = view.bounds
    viewController.view.autoresizingMask = [.width, .height]
    view.addSubview(viewController.view)

    addChild(viewController)
  }
}
