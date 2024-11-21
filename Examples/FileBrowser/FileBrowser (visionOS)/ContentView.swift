import SwiftUI
import SMBClient

struct FileBrowserView: View {
  @State
  private var services = [Service]()
  @State
  private var selection: Service?
  @State
  private var sessions = [ID: SMBClient]()
  @State
  private var showingLoginSheet: Bool = false

  let publisher = NotificationCenter.default.publisher(for: ServiceDiscovery.serviceDidDiscover)

  var body: some View {
    NavigationSplitView {
      List(services, id: \.self, selection: $selection) { (service) in
        NavigationLink(value: service) {
          Label(service.name, systemImage: "server.rack")
            .foregroundStyle(.primary)
        }
      }
      .onChange(of: selection, initial: false) { (oldValue, newValue) in
        if let selection, sessions[selection.id] == nil {
          showingLoginSheet = true
        }
      }
      .onReceive(publisher) { (notification) in
        services = ServiceDiscovery.shared.services.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
      }
      .navigationTitle("Services")
    } detail: {
      if let selection {
        if let client = sessions[selection.id] {
          SharesView(client: client)
            .id(selection)
        }
      }
    }
    .sheet(isPresented: $showingLoginSheet) {
      return
    } content: {
      if let selection = selection {
        let (username, password) = {
          let store = CredentialStore.shared
          if let credential = store.load(server: selection.name) {
            return (credential.username, credential.password)
          } else {
            return ("", "")
          }
        }()

        ConnectServiceView(server: selection.name, username: username, password: password) { (username, password, client) in
          loginSucceeded(server: selection.name, securityDomain: selection.id.rawValue, username: username, password: password, client: client)
          showingLoginSheet = false
        } onCancel: {
          showingLoginSheet = false
        }
      }
    }
  }

  private func loginSucceeded(
    server: String,
    securityDomain: String,
    username: String,
    password: String,
    client: SMBClient
  ) {
    let store = CredentialStore.shared
    store.save(server: server, securityDomain: securityDomain, username: username, password: password)

    sessions[ID(securityDomain)] = client
  }
}

extension Service: Identifiable {}

#Preview(windowStyle: .automatic) {
  FileBrowserView()
}
