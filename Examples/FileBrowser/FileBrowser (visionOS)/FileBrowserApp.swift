import SwiftUI
import SMBClient
import Translation

@main
struct FileBrowserApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self)
  private var appDelegate
  @State
  private var sessionManager = SessionManager()

  var body: some Scene {
    WindowGroup {
      FileBrowserView()
    }
    .environment(\.sessionManager, sessionManager)

    WindowGroup("Video Player", id: "videoPlayer", for: SessionContext.self) { ($context) in
      if let context, let client = sessionManager.sessions[ID(context.domain)] {
        VideoPlayerView(client: client, sessionContext: context)
      }
    }
    .environment(\.sessionManager, sessionManager)
  }
}

class AppDelegate: NSObject, UIApplicationDelegate {
  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey : Any]? = nil
  ) -> Bool {
    ServiceDiscovery.shared.start()
    return true
  }
}


@Observable
class SessionManager {
  var sessions = [ID: SMBClient]()
}

extension EnvironmentValues {
  @Entry var sessionManager = SessionManager()
}

struct SessionContext: Hashable, Codable {
  let domain: String
  let share: String
  let path: String
}
