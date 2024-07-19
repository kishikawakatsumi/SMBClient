import Cocoa

class ConnectServiceWindowController: NSWindowController {
  static func instantiate() -> Self {
    let storyboard = NSStoryboard(name: "ConnectService", bundle: nil)
    let windowController = storyboard.instantiateInitialController() as! Self
    return windowController
  }

  override func windowDidLoad() {
    super.windowDidLoad()
    window?.animationBehavior = .none
  }
}
