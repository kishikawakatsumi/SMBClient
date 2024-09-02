import Cocoa

class ConnectServerViewController: NSViewController {
  @IBOutlet var displayNameField: NSTextField!
  
  @IBOutlet var serverField: NSTextField!
  @IBOutlet var portField: NSTextField!

  @IBOutlet var usernameField: NSTextField!
  @IBOutlet var passwordField: NSTextField!

  @IBOutlet private(set) var rememberPasswordCheckbox: NSButton!

  @IBOutlet var cancelButton: NSButton!
  @IBOutlet var connectButton: NSButton!

  override func viewDidLoad() {
    super.viewDidLoad()

    displayNameField.delegate = self
    serverField.delegate = self
    portField.delegate = self
    usernameField.delegate = self
    passwordField.delegate = self
  }

  override func viewWillAppear() {
    super.viewWillAppear()
    view.window?.makeFirstResponder(serverField)
  }
}

extension ConnectServerViewController: NSTextFieldDelegate {
  func controlTextDidChange(_ obj: Notification) {
    connectButton.isEnabled = !serverField.stringValue.isEmpty && !usernameField.stringValue.isEmpty && !passwordField.stringValue.isEmpty
  }
}
