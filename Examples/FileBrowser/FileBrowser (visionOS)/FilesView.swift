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

  private let treeAccessor: TreeAccessor
  private let path: String

  init(accessor: TreeAccessor, path: String) {
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
        .navigationDestination(for: Route.self) { (route) in
          if route.isDirectory {
            FilesView(accessor: treeAccessor, path: route.path)
          } else {
            let path = URL(fileURLWithPath: route.path)
            if VideoPlayerView.supportedExtensions.contains(path.pathExtension) {
              VideoPlayerView(accessor: treeAccessor, path: route.path)
            } else {

            }
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
