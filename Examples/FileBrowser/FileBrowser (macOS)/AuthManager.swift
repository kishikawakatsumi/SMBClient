import Cocoa
import SMBClient

protocol AuthManager {
  func authenticate() -> Session?
}

class ServiceAuthManager: AuthManager {
  private let id: ID
  private let service: String

  private var authWindowController: ConnectServiceWindowController
  private var authViewController: ConnectServiceViewController

  private var session: Session?

  init(id: ID, service: String) {
    self.id = id
    self.service = service

    authWindowController = ConnectServiceWindowController.instantiate()

    authViewController = authWindowController.contentViewController as! ConnectServiceViewController
    
    authViewController.messageLabel.stringValue = NSLocalizedString(
      String(format: "Enter your name and password for the server “%@”.", service), comment: ""
    )

    authViewController.connectButton.target = self
    authViewController.connectButton.action = #selector(connectAction(_:))

    authViewController.cancelButton.target = self
    authViewController.cancelButton.action = #selector(cancelAction(_:))
  }
  
  func authenticate() -> Session? {
    if let session = SessionManager.shared.session(for: id) {
      return session
    }

    let store = CredentialStore.shared
    if let credential = store.load(server: service) {
      authViewController.usernameField.stringValue = credential.username
      authViewController.passwordField.stringValue = credential.password
    }

    authViewController.connectButton.isEnabled = !authViewController.usernameField.stringValue.isEmpty

    NSApp.runModal(for: authWindowController.window!)
    return session
  }

  @objc
  private func connectAction(_ sender: Any) {
    authViewController.connectButton.isEnabled = false
    
    let username = authViewController.usernameField.stringValue
    let password = authViewController.passwordField.stringValue
    let rememberPassword = authViewController.rememberPasswordCheckbox.state == .on

    Task { @MainActor in
      do {
        let sessionManager = SessionManager.shared
        let session = try await sessionManager.login(
          id: id,
          displayName: nil,
          server: service,
          username: username,
          password: password,
          savePassword: rememberPassword
        )
        self.session = session

        NSApp.stopModal(withCode: .OK)
        authWindowController.window?.orderOut(nil)
      } catch {
        await MainActor.run {
          if let error = error as? ErrorResponse, NTStatus(error.header.status) == .logonFailure {
            authWindowController.window?.performSelector(
              onMainThread: NSSelectorFromString("_shake"),
              with: nil,
              waitUntilDone: true
            )
          } else {
            NSAlert(error: error).runModal()
          }

          authViewController.connectButton.isEnabled = true
        }
      }
    }
  }

  @objc
  private func cancelAction(_ sender: Any) {
    NSApp.stopModal(withCode: .cancel)
    authWindowController.window?.orderOut(nil)
  }
}

class ServerAuthManager: AuthManager {
  private let id: ID

  private var authWindowController: ConnectServerWindowController
  private var authViewController: ConnectServerViewController

  private var session: Session?

  init(id: ID) {
    self.id = id

    authWindowController = ConnectServerWindowController.instantiate()

    authViewController = authWindowController.contentViewController as! ConnectServerViewController

    authViewController.connectButton.target = self
    authViewController.connectButton.action = #selector(connectAction(_:))

    authViewController.cancelButton.target = self
    authViewController.cancelButton.action = #selector(cancelAction(_:))
  }

  func authenticate() -> Session? {
    if let session = SessionManager.shared.session(for: id) {
      return session
    }

    if let server = ServerManager.shared.server(for: id) {
      authViewController.displayNameField.stringValue = server.displayName
      authViewController.serverField.stringValue = server.server
      if let port = server.port {
        authViewController.portField.stringValue = "\(port)"
      }

      let store = CredentialStore.shared
      if let credential = store.load(server: server.server, securityDomain: id.rawValue) {
        authViewController.usernameField.stringValue = credential.username
        authViewController.passwordField.stringValue = credential.password
      }
    }

    authViewController.connectButton.isEnabled = !authViewController.usernameField.stringValue.isEmpty

    NSApp.runModal(for: authWindowController.window!)
    return session
  }

  @objc
  private func connectAction(_ sender: Any) {
    authViewController.connectButton.isEnabled = false

    let displayName = authViewController.displayNameField.stringValue
    let server = authViewController.serverField.stringValue
    let port = authViewController.portField.integerValue
    let username = authViewController.usernameField.stringValue
    let password = authViewController.passwordField.stringValue
    let rememberPassword = authViewController.rememberPasswordCheckbox.state == .on

    Task { @MainActor in
      do {
        let sessionManager = SessionManager.shared
        let session = try await sessionManager.login(
          id: id,
          displayName: displayName,
          server: server,
          port: port == 0 ? nil : port,
          username: username,
          password: password,
          savePassword: rememberPassword
        )

        self.session = session

        NSApp.stopModal(withCode: .OK)
        authWindowController.window?.orderOut(nil)
      } catch {
        await MainActor.run {
          if let error = error as? ErrorResponse, NTStatus(error.header.status) == .logonFailure {
            authWindowController.window?.performSelector(
              onMainThread: NSSelectorFromString("_shake"),
              with: nil,
              waitUntilDone: true
            )
          } else {
            NSAlert(error: error).runModal()
          }

          authViewController.connectButton.isEnabled = true
        }
      }
    }
  }

  @objc
  private func cancelAction(_ sender: Any) {
    NSApp.stopModal(withCode: .cancel)
    authWindowController.window?.orderOut(nil)
  }
}
