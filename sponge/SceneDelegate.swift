import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        guard let windowScene = scene as? UIWindowScene else { return }

        // Root view controller: Landing screen wrapped in a navigation controller
        let landingController = LandingViewController()
        landingController.title = "sponge"

        let navigationController = UINavigationController(rootViewController: landingController)
        navigationController.navigationBar.prefersLargeTitles = true

        let window = UIWindow(windowScene: windowScene)
        window.backgroundColor = .systemBackground
        window.rootViewController = navigationController
        window.makeKeyAndVisible()

        self.window = window
    }
}
