import Cocoa

class ConnectServiceViewController: NSViewController {
  @IBOutlet private(set) var messageLabel: NSTextField!

  @IBOutlet private(set) var usernameField: NSTextField!
  @IBOutlet private(set) var passwordField: NSTextField!

  @IBOutlet private(set) var cancelButton: NSButton!
  @IBOutlet private(set) var connectButton: NSButton!

  @IBOutlet private(set) var rememberPasswordCheckbox: NSButton!

  override func viewDidLoad() {
    super.viewDidLoad()

    usernameField.delegate = self
    passwordField.delegate = self
  }
}

extension ConnectServiceViewController: NSTextFieldDelegate {
  func controlTextDidChange(_ obj: Notification) {
    connectButton.isEnabled = !usernameField.stringValue.isEmpty && !passwordField.stringValue.isEmpty
  }
}
