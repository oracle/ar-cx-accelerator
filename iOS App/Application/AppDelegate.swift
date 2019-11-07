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
import CoreLocation
import os

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, CLLocationManagerDelegate {
    
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
     Reference to the integration broker that will be used by the app.
     This is leveraged to make the back-end integraiton middleware a configurable option while keeping local API calls consistent.
    */
    private(set) var integrationBroker: RemoteIntegrationBroker!
    
    /**
     Object that manages configurations the come from a remote source (ICS, etc.)
    */
    private(set) var appServerConfigs: AppServerConfigs?
    
    /**
     An instance of the core location manager so that we can request coordinates about the user's location that we can pass to service or live experience.
     */
    private var locationManager: CLLocationManager?
    
    /**
     A container for CoreData that can be used to save data to a core data store.
    */
    lazy var appEventsPersistentContainer: NSPersistentContainer = {
        let container = NSPersistentContainer(name: "AppEvents")
        container.loadPersistentStores(completionHandler: { (storeDescription, error) in
            guard let error = error else { return }
            error.log()
        })
        return container
    }()

    // MARK: - UIApplicationDelegate Methods

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        if UserDefaults.standard.object(forKey: AppConfigs.noAppSleep.rawValue) == nil {
            UserDefaults.standard.set(true, forKey: AppConfigs.noAppSleep.rawValue)
        }

        #error("Setting credentials in this manner is insecure and included for example purposes only as part of this accelerator.")
        #warning("Set these parameters if you wish to pre-define an OCI account that will integrate with OCI functions.")
        // OCI F(n) Settings
        if UserDefaults.standard.string(forKey: OciFnConfigs.arFnApplicationDetailsEndpoint.rawValue) == nil || UserDefaults.standard.string(forKey: OciFnConfigs.arFnApplicationDetailsEndpoint.rawValue)!.isEmpty {
            // format is functions.eu-frankfurt-1.oraclecloud.com/v2/fns?app_id=ocid1.fnapp.oc1.eu-frankfurt-1.aaaaaaaaaeykndw4tfmpuscbf6do7p3nyjcoz3a2341imob74xdswn53jmtq
            UserDefaults.standard.set("", forKey: OciFnConfigs.arFnApplicationDetailsEndpoint.rawValue)
        }
        if UserDefaults.standard.string(forKey: OciFnConfigs.tenancyId.rawValue) == nil || UserDefaults.standard.string(forKey: OciFnConfigs.tenancyId.rawValue)!.isEmpty {
            // format is ocid1.tenancy.oc1..aaaaaaaam52qxjxpvfo3qdw4ahtgzqx5wefrevdfvspkldqtvh6byexhwa
            UserDefaults.standard.set("", forKey: OciFnConfigs.tenancyId.rawValue)
        }
        if UserDefaults.standard.string(forKey: OciFnConfigs.authUserId.rawValue) == nil || UserDefaults.standard.string(forKey: OciFnConfigs.authUserId.rawValue)!.isEmpty {
            // format is ocid1.user.oc1..bbbbbbbovqtcwbezdtncyfs7mxorwpy23casrc3cninfr22mjtp65p77y7ya
            UserDefaults.standard.set("", forKey: OciFnConfigs.authUserId.rawValue)
        }
        if UserDefaults.standard.string(forKey: OciFnConfigs.publicKeyFingerprint.rawValue) == nil || UserDefaults.standard.string(forKey: OciFnConfigs.publicKeyFingerprint.rawValue)!.isEmpty {
            // format is 4c:7c:dd:ee:ff:gg:00:39:2e:38:93:2e:b2:08:a6:6d
            UserDefaults.standard.set("", forKey: OciFnConfigs.publicKeyFingerprint.rawValue)
        }
        #warning("You will need a PK for the OCI API signature. You can include the proper key in this project by naming it oci.pem. Otherwise, you can copy and paste it into settings after the app is installed if you do not wish to include a key during compilation / distribution")
        if UserDefaults.standard.string(forKey: OciFnConfigs.privateKey.rawValue) == nil || UserDefaults.standard.string(forKey: OciFnConfigs.privateKey.rawValue)!.isEmpty {
            let setPrivateKey: () -> () = {
                guard let url = Bundle.main.url(forResource: "oci", withExtension: "pem") else { return }
                guard let pk = try? String(contentsOf: url, encoding: .utf8) else { return }
                UserDefaults.standard.set(pk, forKey: OciFnConfigs.privateKey.rawValue)
            }
            
            setPrivateKey()
        }

        #warning("You can use CX infinity to track events that occur within this app for marketing, reporting, and improvement. Fill out the proper backend-id if you wish to implement this feature.")
        // CXInfinity
        if UserDefaults.standard.string(forKey: InfinityConfigs.backendid.rawValue) == nil || UserDefaults.standard.string(forKey: InfinityConfigs.backendid.rawValue)!.isEmpty {
            UserDefaults.standard.set("", forKey: InfinityConfigs.backendid.rawValue)
        }
        if UserDefaults.standard.string(forKey: InfinityConfigs.hostname.rawValue) == nil || UserDefaults.standard.string(forKey: InfinityConfigs.hostname.rawValue)!.isEmpty {
            UserDefaults.standard.set("dc.oracleinfinity.io/v3/", forKey: InfinityConfigs.hostname.rawValue)
        }
        
        AppEventRecorder.shared.record(name: "appDidFinishLaunching", completion: nil)
        
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
        
        let date = Date()
        let urlStr = #"{"url": \#(url.absoluteString)}"#
        AppEventRecorder.shared.record(name: "appLoadedWithUrl", eventStart: date, eventEnd: date, eventLength: 0.0, uiElement: nil, arAnchor: nil, arNode: nil, jsonString: urlStr, completion: nil)
        
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
        
        application.isIdleTimerDisabled = false
        
        guard let arController = self.window?.rootViewController as? ARViewController else { return }
        arController.pauseAllActions()
        
        // End long-term event to track the length of time that the app was active
        if let event = try? AppEventRecorder.shared.getEvent(name: "Application Active") {
            event.eventEnd = Date()
            event.readyToSend = true
            AppEventRecorder.shared.record(event: event, completion: nil)
        }
        
        AppEventRecorder.shared.record(name: "applicationWillResignActive", completion: nil)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        
        // Remove the server configs. They should be refreshed when the application becomes active again.
        self.appServerConfigs = nil
        
        AppEventRecorder.shared.record(name: "applicationWillResignActive", completion: nil)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
        
        AppEventRecorder.shared.record(name: "applicationWillEnterForeground", completion: nil)
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        
        let integrationBackEnd = UserDefaults.standard.string(forKey: AppConfigs.integrationBackEnd.rawValue)
        switch integrationBackEnd {
        case "oci":
            self.integrationBroker = OciBroker.shared
            // Ensure that settings are reloaded when app becomes active in case someone changed the settings while app was closed.
            OciBroker.shared.reloadCredentialsFromSettings()
            break
        // If there were other integration brokers to consider, then implement them here.
        default:
            self.integrationBroker = OciBroker.shared
            // Ensure that settings are reloaded when app becomes active in case someone changed the settings while app was closed.
            OciBroker.shared.reloadCredentialsFromSettings()
            break
        }

        // Create a long-term event to track the length of time that the app was active
        guard let event = try? AppEventRecorder.shared.getEvent(name: "Application Active") else { return }
        event.readyToSend = false
        AppEventRecorder.shared.record(event: event, completion: nil)
        
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
            os_log(.debug, "Idle Timer Disabled: %@", idleTimerFlag ? "true" : "false")
            #endif
        }
        
        AppEventRecorder.shared.record(name: "applicationDidBecomeActive", completion: nil)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        
        AppEventRecorder.shared.record(name: "applicationWillTerminate", completion: nil)
    }
    
    // MARK: - Location Manager Methods
    
    func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        let authorizedStatuses: [CLAuthorizationStatus] = [.authorizedAlways, .authorizedWhenInUse]
        
        if authorizedStatuses.contains(status) {
            if CLLocationManager.isMonitoringAvailable(for: CLBeaconRegion.self) {
                if CLLocationManager.isRangingAvailable() {
                    let uuid = UUID(uuidString: "571D640F-8CAB-4F88-B903-C72B88B7E7F1")! // The UUID of the beacon application
                    // register devices as major/minor pairs
                    let bluePumpRegion = CLBeaconRegion(proximityUUID: uuid, major: 1, identifier: "Blue Pump")
                    let redPumpRegion = CLBeaconRegion(proximityUUID: uuid, major: 2, identifier: "Red Pump")
                    
                    locationManager?.startMonitoring(for: bluePumpRegion)
                    locationManager?.startMonitoring(for: redPumpRegion)
                    locationManager?.startRangingBeacons(in: bluePumpRegion)
                    locationManager?.startRangingBeacons(in: redPumpRegion)
                }
            }
            
            self.locationManager?.startUpdatingLocation()
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didRangeBeacons beacons: [CLBeacon], in region: CLBeaconRegion) {
        if beacons.count > 0 {
            updateDistance(beacons.first!.proximity)
            
            guard let arController = self.window?.rootViewController as? ARViewController else { return }
            //TODO: Update for multiple beacon use
            arController.iBeaconRecognitionHandler(major: Int(truncating: beacons.first!.major), minor: Int(truncating: beacons.first!.minor), completion: nil)
        } else {
            updateDistance(.unknown)
        }
    }
    
    func updateDistance(_ distance: CLProximity) {
        #if DEBUGBEACONS
        switch distance {
        case .far:
            os_log(.debug, "Far iBeacon distance.")
        case .near:
            os_log(.debug, "Near iBeacon distance.")
        case .immediate:
            os_log(.debug, "Immediate iBeacon distance.")
        default:
            //os_log(.debug, "Unknown iBeacon distance.")
            break
        }
        #endif
    }
}
