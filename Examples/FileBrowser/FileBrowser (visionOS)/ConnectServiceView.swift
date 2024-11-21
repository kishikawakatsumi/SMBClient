import SwiftUI
import SMBClient

struct ConnectServiceView: View {
  private enum FocusedField {
    case username
    case password
  }

  @State private var server: String

  @State private var username: String
  @State private var password: String

  private var canSubmit: Bool {
    !username.isEmpty && !password.isEmpty
  }

  @FocusState
  private var focusedField: FocusedField?

  @State private var presentLocalizedAlert: Bool = false
  @State private var localizedError: ErrorResponse? = nil

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
          Label(server, systemImage: "server.rack")
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
      .foregroundStyle(.primary)
      .navigationTitle("Connect to Server")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        Button("Cancel") {
          onCancel()
          dismiss()
        }
      }
      .onAppear {
        focusedField = .username
      }
      .onSubmit {
        guard canSubmit else { return }
        submit()
      }
      .alert(isPresented: $presentLocalizedAlert, error: localizedError) { _ in
        Button("Close") {}
      } message: { error in
        Text(error.failureReason ?? error.recoverySuggestion ?? "")
      }
      .alert("", isPresented: $presentAlert) {
        Button("Close") {}
      } message: {
        Text(error?.localizedDescription ?? "")
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
      } catch let error as ErrorResponse {
        self.localizedError = error
        presentLocalizedAlert = true
      } catch {
        self.error = error
        presentAlert = true
      }
    }
  }
}
