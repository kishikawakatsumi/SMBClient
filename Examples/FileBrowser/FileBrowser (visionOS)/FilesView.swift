import SwiftUI
import SMBClient

struct Route: Hashable {
  let path: String
  let isDirectory: Bool
}

struct FilesView: View {
  @State private var files = [File]()
  @State private var selection: File?
  @State private var isLoading = false
  @State private var errorMessage: String?

  @Environment(\.openWindow) private var openWindow

  private let domain: String
  private let treeAccessor: TreeAccessor
  private let path: String

  init(domain: String, accessor: TreeAccessor, path: String) {
    self.domain = domain
    treeAccessor = accessor
    self.path = path
  }

  var body: some View {
    Group {
      if isLoading {
        ProgressView()
      } else if let errorMessage = errorMessage {
        Text("Error: \(errorMessage)")
          .foregroundColor(.red)
      } else {
        List(files, id: \.self, selection: $selection ) { (file) in
          let subpath = path.isEmpty ? file.name : "\(path)/\(file.name)"
          NavigationLink(value: Route(path: subpath, isDirectory: file.isDirectory)) {
            Label(file.name, systemImage: file.isDirectory ? "folder" : "doc")
          }
        }
        .onChange(of: selection, initial: false) { (oldValue, newValue) in
          if let selection {
            let subpath = path.isEmpty ? selection.name : "\(path)/\(selection.name)"
            let path = URL(fileURLWithPath: subpath)
            if VideoPlayerView.supportedExtensions.contains(path.pathExtension) {
              openWindow(id: "videoPlayer", value: SessionContext(domain: domain, share: treeAccessor.share, path: subpath))
            } else {

            }
          }
        }
        .navigationDestination(for: Route.self) { (route) in
          if route.isDirectory {
            FilesView(domain: domain, accessor: treeAccessor, path: route.path)
          } else {

          }
        }
        .foregroundStyle(.primary)
      }
    }
    .navigationTitle(path.isEmpty ? treeAccessor.share : URL(fileURLWithPath: path).lastPathComponent)
    .task {
      do {
        isLoading = true

        files = try await treeAccessor.listDirectory(path: path)
          .filter { $0.name != "." && $0.name != ".." && !$0.isHidden }
          .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
      } catch {
        errorMessage = "\(error)"
      }
      isLoading = false
    }
  }
}
