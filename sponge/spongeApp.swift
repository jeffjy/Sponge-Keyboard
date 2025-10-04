//
//  spongeApp.swift
//  sponge
//
//  Created by Jeff on 9/25/25.
//

import UIKit

@main
class SpongeAppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let landingController = LandingViewController()
        landingController.title = "sponge"

        let navigationController = UINavigationController(rootViewController: landingController)
        navigationController.navigationBar.prefersLargeTitles = true

        window = UIWindow(frame: UIScreen.main.bounds)
        window?.backgroundColor = .systemBackground
        window?.rootViewController = navigationController
        window?.makeKeyAndVisible()

        return true
    }

    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let config = UISceneConfiguration(name: "Default Configuration", sessionRole: connectingSceneSession.role)
        // Ensure our SceneDelegate drives the window/root view controller
        config.delegateClass = SceneDelegate.self
        return config
    }
}
