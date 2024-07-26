import UIKit
import SMBClient

class SharesViewController: UIViewController, UITableViewDataSource, UITableViewDelegate {
  private let client: SMBClient
  private var shares = [Share]()

  private let tableView = UITableView(frame: .zero, style: .plain)

  init(client: SMBClient) {
    self.client = client
    super.init(nibName: nil, bundle: nil)
  }
  
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }
  
  override func viewDidLoad() {
    super.viewDidLoad()

    navigationItem.title = client.host

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

    Task { @MainActor in
      do {
        let shares = try await self.client.listShares()
          .filter { $0.type.contains(.diskTree) && !$0.type.contains(.ipc) }
          .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        self.shares.append(contentsOf: shares)

        tableView.reloadData()
      } catch {
        let controller = UIAlertController(title: "", message: error.localizedDescription, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: NSLocalizedString("Close", comment: ""), style: .default))
        present(controller, animated: true)
      }
    }
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

  func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
    shares.count
  }

  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueReusableCell(withIdentifier: "cell", for: indexPath)

    cell.imageView?.image = UIImage(systemName: "externaldrive.connected.to.line.below")
    cell.textLabel?.text = shares[indexPath.row].name

    return cell
  }

  func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
    let share = shares[indexPath.row]
    Task { @MainActor in
      _ = try await client.treeConnect(path: share.name)

      let viewController = FilesViewController(client: client, path: "")
      viewController.navigationItem.title = share.name
      
      navigationController?.pushViewController(viewController, animated: true)
    }
  }
}
