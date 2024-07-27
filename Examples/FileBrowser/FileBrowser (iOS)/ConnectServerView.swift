import SwiftUI
import SMBClient

struct ConnectServerView: View {
  enum FocusedField {
    case displayName
    case server
    case port
    case username
    case password
  }

  @State private var displayName: String

  @State private var server: String
  @State private var port: String
  @State private var username: String
  @State private var password: String
  
  private var canSubmit: Bool {
    !server.isEmpty && !username.isEmpty && !password.isEmpty
  }

  @FocusState
  private var focusedField: FocusedField?

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
              .focused($focusedField, equals: .displayName)
          } label: {
            Text("Display Name")
          }
          LabeledContent {
            TextField("Server", text: $server)
              .multilineTextAlignment(.trailing)
              .focused($focusedField, equals: .server)
          } label: {
            Text("Server")
          }
          LabeledContent {
            TextField("Port", text: $port)
              .multilineTextAlignment(.trailing)
              .focused($focusedField, equals: .port)
          } label: {
            Text("Port")
          }
        }
        Section {
          TextField("Username", text: $username)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
            .textContentType(.username)
            .focused($focusedField, equals: .username)
          SecureField("Password", text: $password)
            .textContentType(.password)
            .focused($focusedField, equals: .password)
        } header: {
          Text("Login")
        }
        Section {
          Button("Connect") {
            submit()
          }
          .frame(maxWidth: .infinity)
          .disabled(!canSubmit)
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
      .onAppear {
        focusedField = .server
      }
      .onSubmit {
        guard canSubmit else { return }
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
