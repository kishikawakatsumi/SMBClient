import Cocoa
import SMBClient

class SidebarManager {
  static let shared = SidebarManager()

  static let sidebarDidUpdate = Notification.Name("SidebarManagerSidebarDidUpdate")

  private var tree = Tree()

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
    let serviceHeader = HeaderNode(id: "Services", name: NSLocalizedString("Services", comment: ""))
    let services = ServiceDiscovery.shared.services
    let serviceNodes = services
      .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
      .map { ServerNode(id: $0.id, name: $0.name) }

    let serverHeader = HeaderNode(id: "Servers", name: NSLocalizedString("Servers", comment: ""))

    let servers = ServerManager.shared.servers
    let serverNodes = servers
      .sorted { $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending }
      .map {
        let name: String
        if $0.displayName.isEmpty {
          name = $0.server
        } else {
          name = $0.displayName
        }
        return ServerNode(id: $0.id, name: name)
      }

    let nodes = [serviceHeader] + serviceNodes + [serverHeader] + serverNodes
    var newNodes = [Node]()

    for node in nodes {
      if let index = tree.nodes.firstIndex(of: node){
        let oldNode = tree.nodes[index]
        newNodes.append(oldNode)
        if SessionManager.shared.sessionExists(for: oldNode.id) {
          newNodes.append(contentsOf: tree.children(of: oldNode))
        }
      } else {
        newNodes.append(node)
      }
    }
    tree.nodes = newNodes

    NotificationCenter.default.post(name: Self.sidebarDidUpdate, object: self)

    for node in tree.nodes {
      guard let serverNode = node as? ServerNode else {
        continue
      }
      guard SessionManager.shared.sessionExists(for: serverNode.id) else {
        continue
      }
      if tree.hasChildren(serverNode) {
        continue
      }

      Task { @MainActor in
        await updateChildren(of: serverNode)
      }
    }
  }
}

extension SidebarManager {
  func isItemSelectable(_ item: Any) -> Bool {
    item is ServerNode || item is ShareNode
  }

  func selectRow(_ node: Node) -> Node? {
    if let serverNode = node as? ServerNode {
      let authManager: AuthManager
      if serverNode.path.hasSuffix("._smb._tcp.local") {
        authManager = ServiceAuthManager(id: serverNode.id, service: serverNode.name)
      } else {
        authManager = ServerAuthManager(id: serverNode.id)
      }
      if let _ = authManager.authenticate() {
        return serverNode
      } else {
        return nil
      }
    } else if let shareNode = node as? ShareNode {
      return shareNode
    }

    return nil
  }

  func updateChildren(of node: Node) async {
    switch node {
    case let serverNode as ServerNode:
      if let session = SessionManager.shared.session(for: serverNode.id) {
        let serverRoot = serverNode.path
        
        do {
          let shares = try await session.client.listShares()
            .filter { $0.type == .diskDrive && $0.name != "IPC$" }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
            .map { ShareNode(id: ID("\(serverRoot)/\($0.name)"), device: serverNode.name, name: $0.name, parent: serverNode.id) }

          DataRepository.shared.set(serverRoot, nodes: shares)

          let childlen = tree.children(of: serverNode)
          tree.nodes.removeAll(where: { childlen.contains($0) })
          tree.nodes.append(contentsOf: shares)
        } catch {
          _ = await MainActor.run {
            NSAlert(error: error).runModal()
          }
        }
      } else {
        let childlen = tree.children(of: serverNode)
        tree.nodes.removeAll(where: { childlen.contains($0) })
      }
    default:
      break
    }
  }

  func logoff(_ serverNode: ServerNode) async {
    await SessionManager.shared.logoff(id: serverNode.id)
    
    let children = tree.children(of: serverNode)
    tree.nodes.removeAll(where: { children.contains($0) })

    await MainActor.run {
      NotificationCenter.default.post(name: Self.sidebarDidUpdate, object: self)
    }
  }

  func parent(of node: Node) -> Node? {
    tree.parent(of: node)
  }
}

extension SidebarManager {
  func numberOfChildrenOfItem(_ item: Any?) -> Int {
    if let node = item as? ServerNode {
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
    if let node = item as? ServerNode {
      return tree.children(of: node)[index]
    } else {
      return tree.rootNodes()[index]
    }
  }

  func isItemExpandable(_ item: Any) -> Bool {
    item is ServerNode
  }
}
