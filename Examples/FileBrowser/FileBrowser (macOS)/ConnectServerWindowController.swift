import Cocoa

class ConnectServerWindowController: NSWindowController {
  static func instantiate() -> Self {
    let storyboard = NSStoryboard(name: "ConnectServer", bundle: nil)
    let windowController = storyboard.instantiateInitialController() as! Self
    return windowController
  }

  func runModal() -> NSApplication.ModalResponse {
    return NSApp.runModal(for: window!)
  }

  override func windowDidLoad() {
    super.windowDidLoad()
    window?.animationBehavior = .none
  }
}
