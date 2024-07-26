import UIKit
import AVKit
import SMBClient

class MediaPlayerViewController: UIViewController {
  static let supportedExtensions = {
    let fileTypes: [AVFileType] = AVURLAsset.audiovisualTypes()
    let extensions = fileTypes
      .compactMap { UTType($0.rawValue)?.preferredFilenameExtension }
    return extensions
  }()

  private let client: SMBClient
  private let path: String

  private let playerViewController = AVPlayerViewController()
  private var observation: NSKeyValueObservation?

  init(client: SMBClient, path: String) {
    self.client = client
    self.path = path
    super.init(nibName: nil, bundle: nil)
  }

  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  deinit {
    observation?.invalidate()
  }

  override func viewDidLoad() {
    super.viewDidLoad()

    if let playerView = playerViewController.view {
      playerView.translatesAutoresizingMaskIntoConstraints = false
      view.addSubview(playerView)
      NSLayoutConstraint.activate([
        playerView.topAnchor.constraint(equalTo: view.topAnchor),
        playerView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
        playerView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        playerView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      ])
    }
    addChild(playerViewController)
    playerViewController.didMove(toParent: self)

    Task { @MainActor in
      let asset = SMBAVAsset(client: client, path: path)
      let playerItem = AVPlayerItem(asset: asset)

      let player = AVPlayer(playerItem: playerItem)
      playerViewController.player = player

      observation = playerItem.observe(\.status, options: [.new, .initial]) { (playerItem, change) in
        if playerItem.status == .readyToPlay {
          player.play()
        }
      }
    }
  }
}
