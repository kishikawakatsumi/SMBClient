import SwiftUI

@main
struct FileBrowserApp: App {
  @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

  var body: some Scene {
    WindowGroup {
      FileBrowserView()
    }
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
