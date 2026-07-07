import UIKit

/// Scene delegate for the external display. iOS creates this scene automatically
/// while the app is in the foreground and a monitor is connected — at that point
/// the monitor stops mirroring and shows the desktop instead.
class DesktopSceneDelegate: NSObject, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene,
               willConnectTo session: UISceneSession,
               options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }
        let window = UIWindow(windowScene: windowScene)
        let desktop = DesktopViewController()
        window.rootViewController = desktop
        self.window = window
        window.isHidden = false
        Desk.shared.desktop = desktop
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        if Desk.shared.desktop === window?.rootViewController {
            Desk.shared.desktop = nil
        }
        window = nil
    }
}
