//
//  AppDelegate.swift
//  CocoaPodsVerification
//
//  Created by Nepraunig, Denise on 25.03.19.
//  Copyright © 2019 DeviceKit. All rights reserved.
//

import DeviceKit
import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.

        let device = Device()
        print(device)
        
        return true
    }

}

