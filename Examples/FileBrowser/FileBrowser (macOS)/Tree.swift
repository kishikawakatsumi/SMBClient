import Foundation
import SMBClient

struct Tree<Item: Node & Hashable> {
  var nodes = [Item]()

  func rootNodes() -> [Item] {
    nodes.filter { $0.isRoot }
  }

  func children(of node: Item) -> [Item] {
    nodes.filter { $0.parent == node.id }
  }

  func hasChildren(_ node: Item) -> Bool {
    nodes.contains { $0.parent == node.id }
  }

  func parent(of node: Item) -> Item? {
    nodes.first { $0.id == node.parent }
  }
}

protocol Node {
  var id: ID { get }
  var name: String { get }
  var parent: ID? { get }

  var isRoot: Bool { get }

  func detach() -> Self
}

extension Node {
  var isRoot: Bool { parent == nil }

  static func == (lhs: Self, rhs: Self) -> Bool {
    lhs.id == rhs.id
  }

  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }
}

struct SidebarNode: Node, Hashable {
  let id: ID
  let name: String
  let parent: ID?

  let content: Node

  init(_ content: Node, parent: ID? = nil) {
    id = content.id
    name = content.name
    self.parent = parent

    self.content = content
  }

  func detach() -> Self {
    SidebarNode(content)
  }
}

struct HeaderNode: Node, Hashable {
  let id: ID
  let name: String
  let parent: ID?

  init(_ title: String) {
    self.init(id: ID(title), name: NSLocalizedString(title, comment: ""))
  }

  private init(id: ID, name: String, parent: ID? = nil) {
    self.id = id
    self.name = name
    self.parent = parent
  }

  func detach() -> Self {
    self
  }
}

struct ServerNode: Node, Hashable {
  let id: ID
  let name: String
  let parent: ID?
  var path: String { id.rawValue }

  init(id: ID, name: String, parent: ID? = nil) {
    self.id = id
    self.name = name
    self.parent = parent
  }

  func detach() -> Self {
    ServerNode(id: id, name: name)
  }
}

struct ShareNode: Node, Hashable {
  let id: ID
  let name: String
  let parent: ID?

  let device: String

  init(id: ID, device: String, name: String, parent: ID? = nil) {
    self.id = id
    self.name = name
    self.parent = parent

    self.device = device
  }

  func detach() -> Self {
    ShareNode(id: id, device: device, name: name)
  }
}

struct FileNode: Node, Hashable {
  let id: ID
  let name: String
  let parent: ID?

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
    id = ID(path)
    name = file.name
    self.parent = parent

    self.path = path
    self.file = file
  }

  func detach() -> Self {
    FileNode(path: path, file: file)
  }
}

extension FileNode: CustomStringConvertible {
  var description: String {
    "{\(id.rawValue), \(name), \(file)}"
  }
}
