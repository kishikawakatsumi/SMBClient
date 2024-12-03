import Cocoa
import SMBClient

@MainActor
class DirectoryStructure {
  private let server: String
  private let path: String
  private let treeAccessor: TreeAccessor

  private var tree = Tree<FileNode>()
  private var viewTree = Tree<FileNode>()

  private var searchText = ""
  private var sortDescriptor = NSSortDescriptor(key: "NameColumn", ascending: true)

  var useCache = false {
    didSet {
      if !useCache {
        cache.removeAll()
      }
    }
  }
  private var cache = [FileNode: [FileNode]]()

  init(server: String, path: String, accessor: TreeAccessor) {
    self.server = server
    self.path = path
    treeAccessor = accessor
  }

  func viewTree(_ tree: Tree<FileNode>) -> Tree<FileNode> {
    let nodes = tree.nodes
      .sorted(sortDescriptor)

    let viewTree: Tree<FileNode>
    if !searchText.isEmpty {
      let filteredNodes = nodes.filter {
        $0.name.localizedCaseInsensitiveContains(searchText)
      }
      viewTree = Tree(nodes: filteredNodes)
    } else {
      viewTree = Tree(nodes: nodes)
    }

    return viewTree
  }

  func reload() async throws {
    let nodes = try await listDirectory(path: path, parent: nil)
    tree.nodes = nodes

    viewTree = viewTree(tree)
  }

  func reload(directory path: String, _ outlineView: NSOutlineView) async throws {
    if let fileNode = node(ID(path)) {
      try await expand(fileNode, outlineView)
    } else {
      let nodes = try await listDirectory(path: path, parent: nil)

      tree.nodes = Array(
        Set(nodes)
          .union(
            Set(tree.nodes).subtracting(tree.rootNodes())
          )
      )
      viewTree = viewTree(tree)

      outlineView.reloadData()
    }
  }

  func expand(_ fileNode: FileNode, _ outlineView: NSOutlineView) async throws {
    let path = resolvePath(fileNode)

    let nodes = try await listDirectory(path: path, parent: fileNode)
    let children = children(of: fileNode)

    let (deleted, inserted) = nodeDelta(oldNodes: children, newNodes: nodes)

    tree.nodes = Array(
      Set(nodes)
        .union(
          Set(tree.nodes).subtracting(children)
        )
    )
    viewTree = viewTree(tree)

    outlineView.beginUpdates()
    outlineView.removeItems(at: IndexSet(deleted), inParent: fileNode)
    outlineView.insertItems(at: IndexSet(inserted), inParent: fileNode, withAnimation: children.isEmpty ? .slideDown : [])
    outlineView.endUpdates()
  }

  func update(_ outlineView: NSOutlineView) {
    guard let rootNodes: [FileNode] = DataRepository.shared.nodes(join(server, treeAccessor.share, path)) else {
      return
    }

    let childNodes = tree.nodes
      .filter {
        return $0.isDirectory && outlineView.isItemExpanded($0)
      }
      .reduce(into: [FileNode]()) {
        guard let nodes: [FileNode] = DataRepository.shared.nodes(join(server, treeAccessor.share, $1.path)) else {
          return
        }
        let parent = $1.id
        $0 += nodes.map { FileNode(path: $0.path, file: $0.file, parent: parent) }
      }

    tree.nodes = rootNodes + childNodes

    viewTree = viewTree(tree)

    useCache = true
    outlineView.reloadData()
    useCache = false
  }

  func filter(_ text: String) {
    searchText = text
    viewTree = viewTree(tree)
  }

  func sort(_ descriptor: NSSortDescriptor) {
    sortDescriptor = descriptor
    viewTree = viewTree(tree)
  }

  func resolvePath(_ node: FileNode) -> String {
    var subpath = node.name
    var current: FileNode = node
    while let parent = tree.parent(of: current) {
      subpath = join(parent.name, subpath)
      current = parent
    }

    return join(path, subpath)
  }

  func itemCount() -> Int {
    viewTree.nodes.count
  }

  func availableSpace() async throws -> UInt64 {
    return try await treeAccessor.availableSpace()
  }

  func rootNodes() -> [FileNode] {
    viewTree.rootNodes()
  }

  func parent(of node: FileNode) -> FileNode? {
    viewTree.parent(of: node)
  }

  func children(of node: FileNode) -> [FileNode] {
    if useCache, let children = cache[node] {
      return children
    } else {
      let children = viewTree.children(of: node)
      if useCache {
        cache[node] = children
      }
      return children
    }
  }

  func node(_ id: ID) -> FileNode? {
    viewTree.nodes.first { $0.id == id }
  }

  func node(_ fileURL: URL) -> FileNode? {
    let id = ID(fileURL.pathname)
    return node(id)
  }

  func numberOfChildren(of item: Any?) -> Int {
    if let node = item as? FileNode {
      if node.isExpandable {
        return children(of: node).count
      } else {
        return 0
      }
    } else {
      return viewTree.rootNodes().count
    }
  }

  func child(index: Int, of item: Any?) -> Any {
    if let node = item as? FileNode {
      let children = children(of: node)
      return children[index]
    } else {
      return viewTree.rootNodes()[index]
    }
  }

  func isItemExpandable(_ item: Any) -> Bool {
    if let fileNode = item as? FileNode {
      return fileNode.isExpandable
    }
    return false
  }

  private func listDirectory(path: String, parent: FileNode?) async throws -> [FileNode] {
    let files = try await treeAccessor.listDirectory(path: path)
      .filter { $0.name != "." && $0.name != ".." && !$0.isHidden }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    let nodes = files
      .map { FileNode(path: join(path, $0.name), file: $0, parent: parent?.id) }

    DataRepository.shared.set(join(server, treeAccessor.share, path), nodes: nodes)

    return nodes
  }

  private func nodeDelta(oldNodes: [FileNode], newNodes: [FileNode]) -> (deleted: [Int], inserted: [Int]) {
    let oldSet = Set(oldNodes)
    let newSet = Set(newNodes)

    let deleted: [Int] = oldNodes.enumerated().compactMap { (index, node) in
      return newSet.contains(node) ? nil : index
    }

    let inserted: [Int] = newNodes.enumerated().compactMap { (index, node) in
      return oldSet.contains(node) ? nil : index
    }

    return (deleted, inserted)
  }
}

private extension Array where Element == FileNode {
  func sorted(_ descriptor: NSSortDescriptor) -> [FileNode] {
    let nodes: [FileNode]
    switch descriptor.key {
    case "NameColumn":
      nodes = sorted { $0.name.localizedStandardCompare($1.name) == (descriptor.ascending ? .orderedAscending : .orderedDescending) }
    case "DateColumn":
      nodes = sorted { ($0.lastWriteTime < $1.lastWriteTime) == descriptor.ascending }
    case "SizeColumn":
      nodes = sorted { ($0.size < $1.size) == descriptor.ascending }
    default:
      nodes = self
    }

    return nodes
  }
}
