import SwiftUI
import AVKit
import SMBClient

struct VideoPlayerView: View {
  private let player: AVPlayer
  private let treeAccessor: TreeAccessor

  init(client: SMBClient, sessionContext: SessionContext) {
    treeAccessor = client.treeAccessor(share: sessionContext.share)
    player = AVPlayer(playerItem: AVPlayerItem(asset: SMBAVAsset(accessor: treeAccessor, path: sessionContext.path)))
  }

  var body: some View {
    VideoPlayer(player: player)
      .onAppear {
        player.play()
      }
  }

  static let supportedExtensions = {
    let fileTypes: [AVFileType] = AVURLAsset.audiovisualTypes()
    let extensions = fileTypes
      .compactMap { UTType($0.rawValue)?.preferredFilenameExtension }
    return extensions
  }()
}
