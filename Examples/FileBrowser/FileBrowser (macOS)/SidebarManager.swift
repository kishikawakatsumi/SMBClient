import Cocoa
import SMBClient

class SidebarManager {
  static let shared = SidebarManager()
  static let sidebarDidUpdate = Notification.Name("SidebarManagerSidebarDidUpdate")

  private var tree = Tree<SidebarNode>()

  private init() {
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(serviceDidDiscover(_:)),
      name: ServiceDiscovery.serviceDidDiscover,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(serversDidUpdate(_:)),
      name: ServerManager.serversDidUpdate,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(sessionDidDisconnected(_:)),
      name: SessionManager.sessionDidDisconnected,
      object: nil
    )
  }

  @objc
  private func serviceDidDiscover(_ notification: Notification) {
    updateTree()
  }

  @objc
  private func serversDidUpdate(_ notification: Notification) {
    updateTree()
  }

  @objc
  private func sessionDidDisconnected(_ notification: Notification) {
    updateTree()
  }

  private func updateTree() {
    let services = ServiceDiscovery.shared.services
    let serviceNodes = services
      .map { SidebarNode(ServerNode(id: $0.id, name: $0.name)) }
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }

    let servers = ServerManager.shared.servers
    let serverNodes = servers
      .map {
        let name: String
        if $0.displayName.isEmpty {
          name = $0.server
        } else {
          name = $0.displayName
        }
        return SidebarNode(ServerNode(id: $0.id, name: name))
      }
      .sorted { $0.name.localizedStandardCompare(($1 as SidebarNode).name) == .orderedAscending }

    let children = tree.nodes.reduce(into: [SidebarNode]()) {
      if $1.content is ServerNode {
        $0 += tree.children(of: $1)
      }
    }

    tree.nodes = [SidebarNode(HeaderNode("Services"))] + serviceNodes + [SidebarNode(HeaderNode("Servers"))] + serverNodes
    tree.nodes.append(contentsOf: children)

    NotificationCenter.default.post(name: Self.sidebarDidUpdate, object: self)
  }
}

extension SidebarManager {
  func isItemSelectable(_ item: Any) -> Bool {
    guard let node = item as? SidebarNode else { return false }
    return node.content is ServerNode || node.content is ShareNode
  }

  func selectRow(_ node: SidebarNode) -> SidebarNode? {
    if let serverNode = node.content as? ServerNode {
      let authManager: AuthManager
      if serverNode.path.hasSuffix("._smb._tcp.local.") {
        authManager = ServiceAuthManager(id: serverNode.id, service: serverNode.name)
      } else {
        authManager = ServerAuthManager(id: serverNode.id)
      }
      if let _ = authManager.authenticate() {
        return node
      } else {
        return nil
      }
    } else if node.content is ShareNode {
      return node
    }

    return nil
  }

  func updateChildren(of node: SidebarNode) async {
    switch node.content {
    case let serverNode as ServerNode:
      if let session = SessionManager.shared.session(for: serverNode.id) {
        let serverRoot = serverNode.path
        
        do {
          let shares = try await session.client.listShares()
            .filter { $0.type.contains(.diskTree) && !$0.type.contains(.special) }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { ShareNode(id: ID("\(serverRoot)/\($0.name)"), device: serverNode.name, name: $0.name, parent: serverNode.id) }

          DataRepository.shared.set(serverRoot, nodes: shares)

          let children = tree.children(of: node)
          tree.nodes.removeAll(where: { children.contains($0) })
          tree.nodes.append(contentsOf: shares.map { SidebarNode($0, parent: node.id) })
        } catch {
          _ = await MainActor.run {
            NSAlert(error: error).runModal()
          }
        }
      } else {
        let children = tree.children(of: node)
        tree.nodes.removeAll(where: { children.contains($0) })
      }
    default:
      break
    }
  }

  func logoff(_ node: SidebarNode) async {
    await SessionManager.shared.logoff(id: node.id)
    
    let children = tree.children(of: node)
    tree.nodes.removeAll(where: { children.contains($0) })

    await MainActor.run {
      NotificationCenter.default.post(name: Self.sidebarDidUpdate, object: self)
    }
  }

  func parent(of node: SidebarNode) -> SidebarNode? {
    tree.parent(of: node)
  }
}

extension SidebarManager {
  func numberOfChildrenOfItem(_ item: Any?) -> Int {
    if let node = item as? SidebarNode {
      if tree.hasChildren(node) {
        return tree.children(of: node).count
      } else {
        return 0
      }
    } else {
      return tree.rootNodes().count
    }
  }

  func child(_ index: Int, ofItem item: Any?) -> Any {
    if let node = item as? SidebarNode {
      return tree.children(of: node)[index]
    } else {
      return tree.rootNodes()[index]
    }
  }

  func isItemExpandable(_ item: Any) -> Bool {
    guard let node = item as? SidebarNode else { return false }
    return node.content is ServerNode
  }
}
