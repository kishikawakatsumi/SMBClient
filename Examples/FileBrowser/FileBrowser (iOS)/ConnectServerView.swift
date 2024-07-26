import SwiftUI
import SMBClient

struct ConnectServerView: View {
  @State private var displayName: String
  @State private var server: String
  @State private var port: String
  @State private var username: String
  @State private var password: String

  @State private var presentAlert: Bool = false
  @State private var error: Error? = nil

  @Environment(\.dismiss) private var dismiss

  private let onSuccess: (String, String, String, String, String, SMBClient) -> Void
  private let onCancel: () -> Void

  init(
    displayName: String,
    server: String,
    port: String,
    username: String,
    password: String,
    onSuccess: @escaping (
      _ displayName: String,
      _ server: String,
      _ port: String,
      _ username: String,
      _ password: String,
      _ client: SMBClient
    ) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.displayName = displayName
    self.server = server
    self.port = port
    self.username = username
    self.password = password
    self.onSuccess = onSuccess
    self.onCancel = onCancel
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          LabeledContent {
            TextField("Display Name", text: $displayName)
              .multilineTextAlignment(.trailing)
          } label: {
            Text("Display Name")
          }
          LabeledContent {
            TextField("Server", text: $server)
              .multilineTextAlignment(.trailing)
          } label: {
            Text("Server")
          }
          LabeledContent {
            TextField("Port", text: $port)
              .multilineTextAlignment(.trailing)
          } label: {
            Text("Port")
          }
        }
        Section {
          TextField("Username", text: $username)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .textContentType(.username)
          SecureField("Password", text: $password)
            .textContentType(.password)
        } header: {
          Text("Login")
        }
        Section {
          Button("Connect") {
            submit()
          }
          .frame(maxWidth: .infinity)
        }
      }
      .navigationTitle("Connect to Server")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        Button("Cancel") {
          onCancel()
          dismiss()
        }
      }
      .onSubmit {
        submit()
      }
      .alert(isPresented: $presentAlert) {
        if let error {
          Alert(title: Text("Login Failed"), message: Text(error.localizedDescription), dismissButton: .default(Text("Close")))
        } else {
          Alert(title: Text("Login Failed"), dismissButton: .default(Text("Close")))
        }
      }
    }
  }

  private func submit() {
    Task { @MainActor in
      do {
        let client = SMBClient(host: server, port: Int(port)!)
        try await client.login(username: username, password: password)

        dismiss()
        onSuccess(displayName, server, port, username, password, client)
      } catch {
        presentAlert = true
        self.error = error
      }
    }
  }
}
