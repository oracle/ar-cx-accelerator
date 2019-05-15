//
// *********************************************************************************************
// Copyright © 2019. Oracle and/or its affiliates. All rights reserved.
// Licensed under the Universal Permissive License v 1.0 as shown at
// http://oss.oracle.com/licenses/upl
// *********************************************************************************************
// Accelerator Package: Augmented CX
// Date: 8:21 AM 9/28/18
// *********************************************************************************************
// File: AppDelegate.swift
// *********************************************************************************************
// 

import UIKit
import CoreData
import os

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {
    
    // MARK: - Parameters
    
    /**
     Primary application window
     */
    var window: UIWindow?
    /**
     Store launch options so that we can reference them in an async manner as AR experiences load.
    */
    private(set) var openUrl: URL?
    
    /**
     Dict that will hold launch URL query params.  Logic in the app will remove key/value pairs if needed if the passed param should only be used once.
     */
    var openUrlParams: [String: String]?
    
    /**
     Object that manages configurations the come from a remote source (ICS, etc.)
    */
    private(set) var appServerConfigs: AppServerConfigs?

    // MARK: - UIApplicationDelegate Methods

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if UserDefaults.standard.object(forKey: AppConfigs.noAppSleep.rawValue) == nil {
            UserDefaults.standard.set(true, forKey: AppConfigs.noAppSleep.rawValue)
        }
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        self.openUrl = url
        
        let params = url.query?.components(separatedBy: "&").map({
            $0.components(separatedBy: "=")
        }).reduce(into: [String:String]()) { dict, pair in
            if pair.count == 2 {
                dict[pair[0]] = pair[1]
            }
        }
        
        self.openUrlParams = params
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        
        application.isIdleTimerDisabled = false
        
        guard let arController = self.window?.rootViewController as? ARViewController else { return }
        arController.pauseAllActions()
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        // Remove the server configs. They should be refreshed when the application becomes active again.
        self.appServerConfigs = nil
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        // Get Server Configs
        guard let arController = self.window?.rootViewController as? ARViewController else { return }
        self.appServerConfigs = AppServerConfigs(delegate: arController)
        
        DispatchQueue.main.async {
            // Remove child views if displayed from previous session.
            for childVc in arController.children {
                guard !(childVc is ActivityOverlayViewController) else { break }
                childVc.view.removeFromSuperview()
                childVc.removeFromParent()
            }
            
            // Since this is an AR app and the user may want the screen to remain on while using, let's disable the idle timer.
            let idleTimerFlag = UserDefaults.standard.bool(forKey: "no_sleep")
            application.isIdleTimerDisabled = idleTimerFlag
            #if DEBUG
            os_log("Idle Timer Disabled: %@", idleTimerFlag ? "true" : "false")
            #endif
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:
    }
}
