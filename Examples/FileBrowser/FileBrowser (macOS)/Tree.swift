import Foundation
import SMBClient

struct Tree {
  var nodes = [Node]()

  func rootNodes() -> [Node] {
    return nodes.filter { $0.isRoot }
  }

  func children(of node: Node) -> [Node] {
    return nodes.filter { $0.parent == node.id }
  }

  func hasChildren(_ node: Node) -> Bool {
    return nodes.contains { $0.parent == node.id }
  }

  func parent(of node: Node) -> Node? {
    return nodes.first { $0.id == node.parent }
  }
}

class Node {
  let id: ID
  let name: String
  let parent: ID?

  var isRoot: Bool { parent == nil }

  init(id: ID, name: String, parent: ID? = nil) {
    self.id = id
    self.name = name
    self.parent = parent
  }

  func detach() -> Node {
    Node(id: id, name: name)
  }
}

extension Node: Hashable {
  static func == (lhs: Node, rhs: Node) -> Bool {
    lhs.id == rhs.id
  }
  
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

class HeaderNode: Node {}

class ServerNode: Node {
  var path: String { id.rawValue }

  override func detach() -> Node {
    ServerNode(id: id, name: name)
  }
}

class ShareNode: Node {
  let device: String

  init(id: ID, device: String, name: String, parent: ID? = nil) {
    self.device = device
    super.init(id: id, name: name, parent: parent)
  }

  override func detach() -> Node {
    ShareNode(id: id, device: device, name: name)
  }
}

class FileNode: Node {
  let path: String
  let file: File

  var size: UInt64 { file.size }
  var isDirectory: Bool { file.isDirectory }
  var isHidden: Bool { file.isHidden }
  var isReadOnly: Bool { file.isReadOnly }
  var isSystem: Bool { file.isSystem }
  var isArchive: Bool { file.isArchive }
  var creationTime: Date { file.creationTime }
  var lastAccessTime: Date { file.lastAccessTime }
  var lastWriteTime: Date { file.lastWriteTime }

  var isExpandable: Bool { isDirectory }

  init(path: String, file: File, parent: ID? = nil) {
    self.path = path
    self.file = file
    super.init(id: ID(path), name: file.name, parent: parent)
  }

  override func detach() -> Node {
    FileNode(path: path, file: file)
  }
}

extension FileNode: CustomStringConvertible {
  var description: String {
    "{\(id.rawValue), \(name), \(file)}"
  }
}
