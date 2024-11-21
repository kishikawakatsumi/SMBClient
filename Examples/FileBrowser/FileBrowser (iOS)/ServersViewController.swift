import UIKit
import SwiftUI
import SMBClient

class ServersViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  private let tableView = UITableView(frame: .zero, style: .insetGrouped)

  private var services = [Service]()
  private var sessions = [ID: SMBClient]()

  override func viewDidLoad() {
    super.viewDidLoad()

    navigationItem.title = "Browse"

    let addBarButtonItem = UIBarButtonItem(systemItem: .add)
    addBarButtonItem.target = self
    addBarButtonItem.action = #selector(connectToNewServer(_:))
    navigationItem.rightBarButtonItem = addBarButtonItem


    tableView.dataSource = self
    tableView.delegate = self
    tableView.register(UITableViewCell.self, forCellReuseIdentifier: "cell")

    tableView.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(tableView)
    NSLayoutConstraint.activate([
      view.topAnchor.constraint(equalTo: tableView.topAnchor),
      view.leadingAnchor.constraint(equalTo: tableView.leadingAnchor),
      view.trailingAnchor.constraint(equalTo: tableView.trailingAnchor),
      view.bottomAnchor.constraint(equalTo: tableView.bottomAnchor),
    ])

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(serviceDidDiscover(_:)),
      name: ServiceDiscovery.serviceDidDiscover,
      object: nil
    )
  }

  @objc
  private func serviceDidDiscover(_ notification: Notification) {
    services = ServiceDiscovery.shared.services.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    tableView.reloadData()
  }

  @objc
  private func connectToNewServer(_ sender: UIBarButtonItem) {
    let id = ID(UUID().uuidString)

    let hostingController = UIHostingController(
      rootView: ConnectServerView(
        displayName: "",
        server: "",
        port: "",
        username: "",
        password: ""
      ) { [weak self] (displayName, server, port, username, password, client) in
        guard let self else { return }

        ServerManager.shared.addServer(id: id, displayName: displayName, server: server, port: Int(port))
        loginSucceeded(server: server, securityDomain: id.rawValue, username: username, password: password, client: client)
      } onCancel: { [weak self] in
        guard let self else { return }
        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
          tableView.deselectRow(at: indexPathForSelectedRow, animated: true)
        }
      }
    )
    hostingController.presentationController?.delegate = self

    present(hostingController, animated: true)
  }

  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)

    if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
      tableView.deselectRow(at: indexPathForSelectedRow, animated: animated)
    }
  }

  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    tableView.flashScrollIndicators()
  }

  func numberOfSections(in tableView: UITableView) -> Int {
    2
  }

  func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
    switch section {
    case 0:
      return NSLocalizedString("Services", comment: "")
    case 1:
      return NSLocalizedString("Servers", comment: "")
    default:
      return nil
    }
  }

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    switch section {
    case 0:
      return ServiceDiscovery.shared.services.count
    case 1:
      return ServerManager.shared.servers.count
    default:
      return 0
    }
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

    cell.imageView?.image = UIImage(systemName: "network")

    switch indexPath.section {
    case 0:
      let service = services[indexPath.row]

      cell.textLabel?.text = service.name
      if let _ = sessions[service.id] {
        cell.accessoryType = .disclosureIndicator
      } else {
        cell.accessoryType = .none
      }
    case 1:
      let servers = ServerManager.shared.servers
      let server = servers[indexPath.row]

      cell.textLabel?.text = server.displayName
      if let _ = sessions[server.id] {
        cell.accessoryType = .disclosureIndicator
      } else {
        cell.accessoryType = .none
      }
    default:
      break
    }

    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    Task { @MainActor in
      switch indexPath.section {
      case 0:
        let service = services[indexPath.row]

        if let client = sessions[service.id] {
          let viewController = SharesViewController(client: client)
          navigationController?.pushViewController(viewController, animated: true)
          return
        }

        let username: String
        let password: String
        let store = CredentialStore.shared
        if let credential = store.load(server: service.name) {
          username = credential.username
          password = credential.password
        } else {
          username = ""
          password = ""
        }

        let hostingController = UIHostingController(
          rootView: ConnectServiceView(server: service.name, username: username, password: password) { [weak self] (username, password, client) in
            guard let self else { return }

            loginSucceeded(server: service.name, securityDomain: service.id.rawValue, username: username, password: password, client: client)
          } onCancel: {
            if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
              tableView.deselectRow(at: indexPathForSelectedRow, animated: true)
            }
          }
        )
        hostingController.presentationController?.delegate = self

        present(hostingController, animated: true)
      case 1:
        let servers = ServerManager.shared.servers
        let server = servers[indexPath.row]

        if let client = sessions[server.id] {
          let viewController = SharesViewController(client: client)
          navigationController?.pushViewController(viewController, animated: true)
          return
        }

        let username: String
        let password: String
        let store = CredentialStore.shared
        if let credential = store.load(server: server.server, securityDomain: server.id.rawValue) {
          username = credential.username
          password = credential.password
        } else {
          username = ""
          password = ""
        }

        let port: String?
        if let p = server.port {
          port = String(p)
        } else {
          port = nil
        }

        let hostingController = UIHostingController(
          rootView: ConnectServerView(
            displayName: server.displayName,
            server: server.server,
            port: port ?? "",
            username: username,
            password: password
          ) { [weak self] (displayName, serverName, port, username, password, client) in
            guard let self else { return }

            ServerManager.shared.addServer(id: server.id, displayName: displayName, server: serverName, port: Int(port))
            loginSucceeded(server: serverName, securityDomain: server.id.rawValue, username: username, password: password, client: client)
          } onCancel: {
            if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
              tableView.deselectRow(at: indexPathForSelectedRow, animated: true)
            }
          }
        )
        hostingController.presentationController?.delegate = self

        present(hostingController, animated: true)
      default:
        break
      }
    }
  }

  func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
    indexPath.section == 1
  }

  func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
    if editingStyle == .delete && indexPath.section == 1 {
      let servers = ServerManager.shared.servers
      let server = servers[indexPath.row]

      ServerManager.shared.removeServer(server)
      tableView.deleteRows(at: [indexPath], with: .automatic)
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

    tableView.reloadData()

    let viewController = SharesViewController(client: client)
    navigationController?.pushViewController(viewController, animated: true)
  }
}

extension ServersViewController: UIAdaptivePresentationControllerDelegate {
  func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
    if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
      tableView.deselectRow(at: indexPathForSelectedRow, animated: true)
    }
  }
}
