import Cocoa

class SidebarCellView: NSTableCellView {
  var ejectAction: () -> Void = {}
  @IBOutlet private(set) var ejectButton: NSButton!

  @IBAction
  func ejectAction(_ sender: NSButton) {
    ejectAction()
  }
}
