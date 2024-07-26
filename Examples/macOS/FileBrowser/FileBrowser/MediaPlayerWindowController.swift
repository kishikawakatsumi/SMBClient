import Cocoa
import AVKit
import SMBClient

private let storyboardID = "MediaPlayerWindowController"

class MediaPlayerWindowController: NSWindowController, NSWindowDelegate {
  static let supportedExtensions = {
    let fileTypes: [AVFileType] = AVURLAsset.audiovisualTypes()
    let extensions = fileTypes
      .compactMap { UTType($0.rawValue)?.preferredFilenameExtension }
    return extensions
  }()

  private let client: SMBClient
  private let path: String

  private var observation: NSKeyValueObservation?
  private var windowController: NSWindowController?

  static func instantiate(path: String, client: SMBClient) -> Self {
    let storyboard = NSStoryboard(name: storyboardID, bundle: nil)
    return storyboard.instantiateController(identifier: storyboardID) { (coder) in
      Self(coder: coder, path: path, client: client)
    }
  }

  required init?(coder: NSCoder, path: String, client: SMBClient) {
    self.path = path
    self.client = client

    super.init(coder: coder)
  }

  required init?(coder: NSCoder) {
    return nil
  }

  deinit {
    observation?.invalidate()
  }

  override func windowDidLoad() {
    super.windowDidLoad()

    guard let window else { return }

    window.appearance = NSAppearance(named: .darkAqua)
    window.title = URL(fileURLWithPath: path).lastPathComponent

    window.delegate = self

    guard let videoPlayerViewController = contentViewController as? MediaPlayerViewController else { return }

    let asset = SMBAVAsset(client: client, path: path)
    let playerItem = AVPlayerItem(asset: asset)

    let player = AVPlayer(playerItem: playerItem)
    videoPlayerViewController.playerView.player = player

    asset.loadTracks(withMediaType: .video) { (tracks, error) in
      guard let track = tracks?.first else { return }
      Task {
        let naturalSize = try await track.load(.naturalSize)

        await MainActor.run {
          guard let currentScreen = NSScreen.screens.first(where: { $0 == window.screen }) else {
            return
          }

          let rect = AVMakeRect(
            aspectRatio: CGSize(width: naturalSize.width, height: naturalSize.height),
            insideRect: currentScreen.visibleFrame
          )
          let contentSize = NSSize(width: min(rect.width, naturalSize.width), height: min(rect.height, naturalSize.height))

          window.setContentSize(contentSize)
          window.center()
        }
      }
    }

    windowController = self
  }

  func windowWillClose(_ notification: Notification) {
    windowController = nil
  }
}

class MediaPlayerViewController: NSViewController {
  @IBOutlet var playerView: AVPlayerView!

  override func viewDidAppear() {
    super.viewDidAppear()
    playerView.player?.play()
  }
}
