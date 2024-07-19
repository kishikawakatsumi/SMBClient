import Cocoa
import SMBClient

@MainActor
class DirectoryStructure {
  private let server: String
  private let path: String

  private var tree = Tree()
  private var viewTree = Tree()

  private var searchText = ""
  private var sortDescriptor = NSSortDescriptor(key: "NameColumn", ascending: true)

  private let client: SMBClient

  init(server: String, path: String, client: SMBClient) {
    self.server = server
    self.path = path
    self.client = client
  }

  func viewTree(_ tree: Tree) -> Tree {
    let nodes = tree.nodes
      .compactMap {
        guard let node = $0 as? FileNode else { return nil }
        return node
      }
      .sorted(sortDescriptor)

    let viewTree: Tree
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

  func reload() async {
    let nodes = await listDirectory(path: path, parent: nil)

    tree.nodes.removeAll()
    tree.nodes.append(contentsOf: nodes)

    viewTree = viewTree(tree)
  }

  func reload(directory path: String, _ outlineView: NSOutlineView) async {
    if let fileNode = node(ID(path)) {
      await expand(fileNode, outlineView)
    } else {
      let nodes = await listDirectory(path: path, parent: nil)
      let rootNodes = tree.rootNodes()

      let newNodes = mergeNodes(oldNodes: rootNodes, newNodes: nodes)

      tree.nodes.removeAll { rootNodes.contains($0) }
      tree.nodes.append(contentsOf: newNodes)

      viewTree = viewTree(tree)

      outlineView.reloadData()
    }
  }

  func update(_ outlineView: NSOutlineView) {
    if let nodes = DataRepository.shared.nodes(join(server, path)) {
      tree.nodes = nodes
    }

    let expandedNodes = tree.nodes
      .filter {
        guard let fileNode = $0 as? FileNode else { return false }
        return fileNode.isDirectory && outlineView.isItemExpanded(fileNode)
      }
      .compactMap {
        $0 as? FileNode
      }
    for node in expandedNodes {
      if let nodes = DataRepository.shared.nodes(join(server, node.path)) {
        tree.nodes.removeAll { nodes.contains($0) }
        tree.nodes.append(contentsOf: nodes)
      }
    }

    viewTree = viewTree(tree)
    outlineView.reloadData()
  }

  func filter(_ text: String) {
    searchText = text
    viewTree = viewTree(tree)
  }

  func sort(_ descriptor: NSSortDescriptor) {
    sortDescriptor = descriptor
    viewTree = viewTree(tree)
  }

  func expand(_ fileNode: FileNode, _ outlineView: NSOutlineView) async {
    let path = resolvePath(fileNode)

    let nodes = await listDirectory(path: path, parent: fileNode)
    let childlen = children(of: fileNode)

    let (deleted, inserted) = nodeDelta(oldNodes: childlen, newNodes: nodes)
    let newNodes = mergeNodes(oldNodes: childlen, newNodes: nodes)

    tree.nodes.removeAll { childlen.contains($0) }
    tree.nodes.append(contentsOf: newNodes)

    viewTree = viewTree(tree)

    outlineView.removeItems(at: IndexSet(deleted), inParent: fileNode)
    outlineView.insertItems(at: IndexSet(inserted), inParent: fileNode, withAnimation: childlen.isEmpty ? .slideDown : [])
  }

  func resolvePath(_ node: Node) -> String {
    var subpath = node.name
    var current: Node = node
    while let parent = tree.parent(of: current) {
      subpath = join(parent.name, subpath)
      current = parent
    }

    return join(path, subpath)
  }

  func itemCount() -> Int {
    viewTree.nodes.count
  }

  func parent(of node: Node) -> Node? {
    viewTree.parent(of: node)
  }

  func children(of node: Node) -> [Node] {
    viewTree.children(of: node)
  }

  func node(_ id: ID) -> FileNode? {
    return viewTree.nodes.first { $0.id == id } as? FileNode
  }

  func node(_ fileURL: URL) -> FileNode? {
    let id = ID(fileURL.pathname)
    return node(id)
  }

  func numberOfChildren(of item: Any?) -> Int {
    if let node = item as? FileNode {
      if node.isExpandable {
        return viewTree.children(of: node).count
      } else {
        return 0
      }
    } else {
      return viewTree.rootNodes().count
    }
  }

  func child(index: Int, of item: Any?) -> Any {
    if let node = item as? FileNode {
      return viewTree.children(of: node)[index]
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

  private func listDirectory(path: String, parent: FileNode?) async -> [Node] {
    do {
      let files = try await client.listDirectory(path: path)
        .filter { $0.name != "." && $0.name != ".." && !$0.isHidden }
        .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
      let nodes = files
        .map { FileNode(path: join(path, $0.name), file: $0, parent: parent?.id) }

      DataRepository.shared.set(join(server, path), nodes: nodes)

      return nodes
    } catch {
      NSAlert(error: error).runModal()
    }

    return DataRepository.shared.nodes(join(server, path)) ?? []
  }

  private func nodeDelta(oldNodes: [Node], newNodes: [Node]) -> (deleted: [Int], inserted: [Int]) {
    let deleted: [Int] = oldNodes.enumerated().compactMap { (index, node) in
      if let _ = newNodes.firstIndex(of: node) {
        return nil
      } else {
        return index
      }
    }
    let inserted: [Int] = newNodes.enumerated().compactMap { (index, node) in
      if let _ = oldNodes.firstIndex(of: node) {
        return nil
      } else {
        return index
      }
    }

    return (deleted, inserted)
  }

  private func mergeNodes(oldNodes: [Node], newNodes: [Node]) -> [Node] {
    var mergedNodes = [Node]()
    for newNode in newNodes {
      if let index = oldNodes.firstIndex(of: newNode) {
        mergedNodes.append(oldNodes[index])
      } else {
        mergedNodes.append(newNode)
      }
    }

    mergedNodes = mergedNodes
      .compactMap {
        guard let node = $0 as? FileNode else { return nil }
        return node
      }
      .sorted(sortDescriptor)

    return mergedNodes
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
