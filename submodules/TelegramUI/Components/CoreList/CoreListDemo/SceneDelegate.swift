//
//  SceneDelegate.swift
//  CoreListDemo
//
//  Created by Isaac on 21/03/2026.
//

import UIKit

class SceneDelegate: UIResponder, UIWindowSceneDelegate {

    var window: UIWindow?


    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        // Two production demos — the virtualized list and the custom physics scroll view — plus the
        // debug gesture recorder, which captures real UIScrollView ground truth into the fixtures the
        // physics replica is regression-tested against. This file is excluded from the Bazel
        // `CoreList` library, so the recorder tab exists only in the standalone demo app.
        guard let windowScene = scene as? UIWindowScene else { return }

        let listVC = ViewController()
        listVC.tabBarItem = UITabBarItem(title: "Virtual List",
                                         image: UIImage(systemName: "list.bullet"), tag: 0)
        let physicsVC = PhysicsScrollDemoViewController()
        physicsVC.tabBarItem = UITabBarItem(title: "Physics Scroll",
                                            image: UIImage(systemName: "scroll"), tag: 1)

        let abVC = ScrollComparisonViewController()
        abVC.tabBarItem = UITabBarItem(title: "A/B",
                                       image: UIImage(systemName: "rectangle.split.2x1"), tag: 3)

        let recorderVC = ScrollRecorderViewController()
        recorderVC.tabBarItem = UITabBarItem(title: "Recorder",
                                             image: UIImage(systemName: "record.circle"), tag: 2)

        // Measures the commit-to-display depth the baked flight's `beginTime` is implicitly betting on.
        let pipelineVC = PipelineDepthViewController()
        pipelineVC.tabBarItem = UITabBarItem(title: "Pipeline",
                                             image: UIImage(systemName: "timer"), tag: 4)

        let tabs = UITabBarController()
        tabs.viewControllers = [listVC, physicsVC, abVC, recorderVC, pipelineVC]

        let window = UIWindow(windowScene: windowScene)
        window.rootViewController = tabs
        self.window = window
        window.makeKeyAndVisible()

        // `-pipelineProbe` opens the Pipeline tab and starts it with no interaction at all, so the
        // measurement can be driven entirely from the host: launch, screenshot, read the separation.
        if ProcessInfo.processInfo.arguments.contains("-pipelineProbe") {
            tabs.selectedIndex = 4
            DispatchQueue.main.async { PipelineDepthProbe.shared.start() }
        }
    }

    func sceneDidDisconnect(_ scene: UIScene) {
        // Called as the scene is being released by the system.
        // This occurs shortly after the scene enters the background, or when its session is discarded.
        // Release any resources associated with this scene that can be re-created the next time the scene connects.
        // The scene may re-connect later, as its session was not necessarily discarded (see `application:didDiscardSceneSessions` instead).
    }

    func sceneDidBecomeActive(_ scene: UIScene) {
        // Called when the scene has moved from an inactive state to an active state.
        // Use this method to restart any tasks that were paused (or not yet started) when the scene was inactive.
    }

    func sceneWillResignActive(_ scene: UIScene) {
        // Called when the scene will move from an active state to an inactive state.
        // This may occur due to temporary interruptions (ex. an incoming phone call).
    }

    func sceneWillEnterForeground(_ scene: UIScene) {
        // Called as the scene transitions from the background to the foreground.
        // Use this method to undo the changes made on entering the background.
    }

    func sceneDidEnterBackground(_ scene: UIScene) {
        // Called as the scene transitions from the foreground to the background.
        // Use this method to save data, release shared resources, and store enough scene-specific state information
        // to restore the scene back to its current state.
    }


}
