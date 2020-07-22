//
//  AppDelegate.swift
//  NSKCameraControllerTest
//
//  Created by NSSimpleApps on 28.02.2020.
//  Copyright © 2020 NSSimpleApps. All rights reserved.
//

import UIKit
import NSKCameraController

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    var window: UIWindow?
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if #available(iOS 13.0, *) {
        } else {
            self.window = UIWindow(frame: UIScreen.main.bounds)
            self.window?.rootViewController = UINavigationController(rootViewController: ViewController())
            self.window?.makeKeyAndVisible()
        }
        
        return true
    }
}

