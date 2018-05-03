//
//  AppDelegate.swift
//  keyn
//
//  Created by bas on 29/09/2017.
//  Copyright © 2017 keyn. All rights reserved.
//

import UIKit
import AWSCore
import UserNotifications
import os.log
import LocalAuthentication

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {

        // FOR TESTING PURPOSES
        //Session.deleteAll() // Uncomment if session keys should be cleaned before startup
        //Account.deleteAll()   // Uncomment if passwords should be cleaned before startup
        //try? Seed.delete()      // Uncomment if you want to force seed regeneration
        //try? Keychain.sharedInstance.delete(id: "snsDeviceEndpointArn", service: "io.keyn.aws") // Uncomment to delete snsDeviceEndpointArn from Keychain
        //BackupManager.sharedInstance.deleteAll()


        // Override point for customization after application launch.
        fetchAWSIdentification()
        registerForPushNotifications()
        
        let _ = AuthenticationGuard.sharedInstance
        let _: LAError? = nil
        
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSNotification.Name.UIPasteboardChanged, object: nil, queue: nil, using: handlePasteboardChangeNotification)
        
        // Set purple line under NavigationBar
        UINavigationBar.appearance().shadowImage = UIImage(color: UIColor(rgb: 0x4932A2), size: CGSize(width: UIScreen.main.bounds.width, height: 1))
        
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        print("TODO: Enable stuff")
        AWS.sharedInstance.snsRegistration(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // The token is not currently available.
        print("Remote notification support is unavailable due to error: \(error.localizedDescription)")
        print("TODO: Disable stuff")
    }

    // Called when a notification is delivered to a foreground app.
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        
        // TODO: Find out why we cannot pass RequestType in userInfo..
        guard let browserMessageTypeValue = notification.request.content.userInfo["requestType"] as? Int, let browserMessageType = BrowserMessageType(rawValue: browserMessageTypeValue) else {
            completionHandler([])
            return
        }

        guard let sessionID = notification.request.content.userInfo["sessionID"] as? String else {
            completionHandler([])
            return
        }
        if browserMessageType == .end {
            // TODO: If errors are thrown here, they should be logged. App will now crash on errors
            try! Session.getSession(id: sessionID)?.delete(includingQueue: false)
            if let rootViewController = window?.rootViewController as? RootViewController, let devicesNavigationController = rootViewController.viewControllers?[1] as? DevicesNavigationController {
                for viewController in devicesNavigationController.viewControllers {
                    if let devicesViewController = viewController as? DevicesViewController {
                        if devicesViewController.isViewLoaded {
                            devicesViewController.removeSessionFromTableView(sessionID: sessionID)
                        }
                    }
                }
            }
            completionHandler([.alert, .sound])
        } else {
            guard let siteID = notification.request.content.userInfo["siteID"] as? Int else {
                completionHandler([])
                return
            }
            guard let siteName = notification.request.content.userInfo["siteName"] as? String else {
                completionHandler([])
                return
            }
            guard let browserTab = notification.request.content.userInfo["browserTab"] as? Int else {
                completionHandler([])
                return
            }

            DispatchQueue.main.async {
                AuthenticationGuard.sharedInstance.launchRequestView(with: PushNotification(sessionID: sessionID, siteID: siteID, siteName: siteName, browserTab: browserTab, requestType: browserMessageType))
            }
            completionHandler([.sound])
        }
    }

    // Called to let your app know which action was selected by the user for a given notification.
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        os_log("Background notification called")
        // TODO: Find out why we cannot pass RequestType in userInfo..
        guard let browserMessageTypeValue = response.notification.request.content.userInfo["requestType"] as? Int, let browserMessageType = BrowserMessageType(rawValue: browserMessageTypeValue) else {
            completionHandler()
            return
        }

        guard let sessionID = response.notification.request.content.userInfo["sessionID"] as? String else {
            completionHandler()
            return
        }

        if browserMessageType == .end {
            // TODO: If errors are thrown here, they should be logged. App now crashes.
            try! Session.getSession(id: sessionID)?.delete(includingQueue: false)
        } else {
            guard let siteID = response.notification.request.content.userInfo["siteID"] as? Int else {
                completionHandler()
                return
            }
            guard let siteName = response.notification.request.content.userInfo["siteName"] as? String else {
                completionHandler()
                return
            }
            guard let browserTab = response.notification.request.content.userInfo["browserTab"] as? Int else {
                completionHandler()
                return
            }

            if response.notification.request.content.categoryIdentifier == "PASSWORD_REQUEST" {
//                if response.actionIdentifier == "ACCEPT" {
//                                    cancelAutoAuthentication()
//                                    notificationUserInfo = [
//                                        "sessionID": sessionID,
//                                        "siteID": siteID,
//                                        "accepted": "true"
//                                    ]
//
//                    // Directly send password? Is this a security risk? Should be tested
//                    if let account = try! Account.get(siteID: siteID), let session = try! Session.getSession(id: sessionID) {
//                        try! session.sendCredentials(account: account, browserTab: browserTab, type: browserMessageType)
//                    }
//                }

                if response.actionIdentifier == "ACCEPT" {
                    // This should present request page --> Yes / NO. AUthentication after or before?
                    AuthenticationGuard.sharedInstance.launchRequestView(with: PushNotification(sessionID: sessionID, siteID: siteID, siteName: siteName, browserTab: browserTab, requestType: browserMessageType))
                }
            }

            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                // This should present request page --> Yes / NO. AUthentication after or before?
                AuthenticationGuard.sharedInstance.launchRequestView(with: PushNotification(sessionID: sessionID, siteID: siteID, siteName: siteName, browserTab: browserTab, requestType: browserMessageType))
            }

        }
        completionHandler()
    }

    func application(_ application: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        // App opened with url
        return true
    }

    // Sent when the application is about to move from active to inactive state.
    // This can occur for certain types of temporary interruptions (such as an incoming phone call
    // or SMS message) or when the user quits the application and it begins the transition to the background state.
    // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks.
    // Games should use this method to pause the game.
    func applicationWillResignActive(_ application: UIApplication) {
    }

    // Use this method to release shared resources, save user data, invalidate timers,
    // and store enough application state information to restore your application to its
    // current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    func applicationDidEnterBackground(_ application: UIApplication) {
    }


    // Called as part of the transition from the background to the active state;
    // here you can undo notificationUserInfo = nil
    func applicationWillEnterForeground(_ application: UIApplication) {
        // TODO: Can we discover here if an app was launched with a remote notification and present the request view controller instead of login?
        handlePendingEndSessionNotifications()
    }

    // Restart any tasks that were paused (or not yet started) while the application was inactive.
    // If the application was previously in the background, optionally refresh the user interface.
    func applicationDidBecomeActive(_ application: UIApplication) {
        
        // Clean up notifications
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    private func handlePasteboardChangeNotification(notification: Notification) {
        let pasteboard = UIPasteboard.general
        guard let text = pasteboard.string, text != "" else {
            return
        }
        
        let pasteboardVersion = pasteboard.changeCount
        let clearPasteboardTimeout = 60.0 // TODO: hardcoded for now. This should be editable in settings I guess?
        
        var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
        backgroundTask = UIApplication.shared.beginBackgroundTask { [weak self] in
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = UIBackgroundTaskInvalid
        }
        
        DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + clearPasteboardTimeout) {
            if pasteboardVersion == pasteboard.changeCount {
                pasteboard.string = ""
            }
            
            if backgroundTask != UIBackgroundTaskInvalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
            }
        }
    }

    private func handlePendingEndSessionNotifications() {
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { (notifications) in
            for notification in notifications {
                if let browserMessageTypeValue = notification.request.content.userInfo["requestType"] as? Int,
                    let browserMessageType = BrowserMessageType(rawValue: browserMessageTypeValue),
                    let sessionID = notification.request.content.userInfo["sessionID"] as? String,
                    browserMessageType == .end
                {
                    try! Session.getSession(id: sessionID)?.delete(includingQueue: false)
                }
            }
        }
    }
    
    private func launchInitialView() {
        // If there is no seed in the keychain (first run or if deleteSeed() has been called, a new seed will be generated and stored in the Keychain. Otherwise LoginController is launched.
        self.window = UIWindow(frame: UIScreen.main.bounds)
        let viewController: UIViewController?
        if !Seed.exists() {
            let storyboard: UIStoryboard = UIStoryboard(name: "Initialisation", bundle: nil)
            let rootController = storyboard.instantiateViewController(withIdentifier: "InitialisationViewController")
            viewController = rootController
        } else {
            let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            viewController = storyboard.instantiateViewController(withIdentifier: "RootController") as! RootViewController
        }
        
        self.window?.rootViewController = viewController
        self.window?.makeKeyAndVisible()
    }
    
    private func fetchAWSIdentification() {
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:. EUCentral1,
                                                                identityPoolId: "eu-central-1:7ab4f662-00ed-4a86-a03e-533c43a44dbe")

        let configuration = AWSServiceConfiguration(region: .EUCentral1, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
    }

    @available(iOS 10.0, *)
    private func registerForPushNotifications() {
        // TODO: Add if #available(iOS 10.0, *), see https://medium.com/@thabodavidnyakalloklass/ios-push-with-amazons-aws-simple-notifications-service-sns-and-swift-made-easy-51d6c79bc206
//        let acceptRequestAction = UNNotificationAction(identifier: "ACCEPT",
//                                                       title: "Accept",
//                                                       options: UNNotificationActionOptions(rawValue: 0))
//        let rejectRequestAction = UNNotificationAction(identifier: "REJECT",
//                                                       title: "Reject",
//                                                       options: .destructive)
        let passwordRequestNotificationCategory = UNNotificationCategory(identifier: "PASSWORD_REQUEST",
                                                                         actions: [],
                                                                         intentIdentifiers: [],
                                                                         options: .customDismissAction)
        let endSessionNotificationCategory = UNNotificationCategory(identifier: "END_SESSION",
                                                                    actions: [],
                                                                    intentIdentifiers: [],
                                                                    options: UNNotificationCategoryOptions(rawValue: 0))
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([passwordRequestNotificationCategory, endSessionNotificationCategory])
        center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            if granted {
                DispatchQueue.main.sync {
                    UIApplication.shared.registerForRemoteNotifications()
                    self.launchInitialView()
                }
            } else {
                // TODO: Do stuff if unsuccessful… Inform user that app can't be used without push notifications
            }
        }

    }

}
