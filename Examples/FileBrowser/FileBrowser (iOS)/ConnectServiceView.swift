import SwiftUI
import SMBClient

struct ConnectServiceView: View {
  @State private var server: String

  @State private var username: String
  @State private var password: String

  @State private var presentAlert: Bool = false
  @State private var error: Error? = nil

  @Environment(\.dismiss) private var dismiss

  private let onSuccess: (String, String, SMBClient) -> Void
  private let onCancel: () -> Void

  init(
    server: String,
    username: String,
    password: String,
    onSuccess: @escaping (_ username: String, _ password: String, _ client: SMBClient) -> Void,
    onCancel: @escaping () -> Void
  ) {
    self.server = server
    self.username = username
    self.password = password
    self.onSuccess = onSuccess
    self.onCancel = onCancel
  }

  var body: some View {
    NavigationStack {
      Form {
        Section {
          Label(server, systemImage: "network")
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
          .disabled(username.isEmpty || password.isEmpty)
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
        let client = SMBClient(host: server)
        try await client.login(username: username, password: password)

        dismiss()
        onSuccess(username, password, client)
      } catch {
        presentAlert = true
        self.error = error
      }
    }
  }
}
