import SwiftUI
import SMBClient

struct SharesView: View {
  @State private var shares = [Share]()
  @State private var selection: Share?
  @State private var isLoading = false
  @State private var errorMessage: String?

  private let client: SMBClient
  private var host: String
  private let id = UUID()

  init(client: SMBClient) {
    self.client = client
    host = client.host
  }

  var body: some View {
    Group {
      if isLoading {
        ProgressView()
      } else if let errorMessage = errorMessage {
        Text("Error: \(errorMessage)")
          .foregroundColor(.red)
      } else {
        NavigationStack {
          List(shares, id: \.self, selection: $selection ) { (share) in
            NavigationLink(value: share.name) {
              Label(share.name, systemImage: "externaldrive.connected.to.line.below")
            }
          }
          .navigationDestination(for: String.self) { (share) in
            FilesView(accessor: client.treeAccessor(share: share), path: "")
          }
        }
        .foregroundStyle(.primary)
      }
    }
    .navigationTitle(host)
    .task {
      do {
        isLoading = true
        
        shares = try await client.listShares()
          .filter { $0.type.contains(.diskTree) && !$0.type.contains(.special) }
          .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
      } catch {
        errorMessage = "\(error)"
      }
      isLoading = false
    }
  }
}
