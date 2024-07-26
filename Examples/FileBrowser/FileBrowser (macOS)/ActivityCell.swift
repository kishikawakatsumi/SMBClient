import Cocoa

class ActivityCell: NSTableCellView {
  @IBOutlet private(set) var progressIndicator: NSProgressIndicator!
  @IBOutlet private(set) var messageLabel: NSTextField!

  override func awakeFromNib() {
    super.awakeFromNib()
    if let font = messageLabel.font {
      messageLabel.font = .monospacedDigitSystemFont(ofSize: font.pointSize, weight: .regular)
    }
  }
}
