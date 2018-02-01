
//
//  AppDelegate.swift
//  keyn
//
//  Created by bas on 29/09/2017.
//  Copyright © 2017 keyn. All rights reserved.
//

import UIKit
import AWSCore
import AWSCognito
import AWSSNS
import UserNotifications


@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    var notificationUserInfo: [String:String]?
    var authenticated = false
    var requestInProgress = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        // FOR TESTING PURPOSES
        //deleteSessionKeys() // Uncomment if session keys should be cleaned before startup
        //deletePasswords()   // Uncomment if passwords should be cleaned before startup
        //deleteSeed()      // Uncomment if you want to force seed regeneration
        
        // Override point for customization after application launch.
        notificationUserInfo = nil
        fetchAWSIdentification()
        launchInitialView()
        registerForPushNotifications()

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
        guard let siteID = notification.request.content.userInfo["data"] as? String else {
            completionHandler([])
            return
        }
        guard let sessionID = notification.request.content.userInfo["id"] as? String else {
            completionHandler([])
            return
        }
        DispatchQueue.main.async {
            self.launchRequestView(sessionID: sessionID, siteID: siteID, sandboxed: false)
        }
        completionHandler([.sound])
    }

    // Called to let your app know which action was selected by the user for a given notification.
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        guard let siteID = response.notification.request.content.userInfo["data"] as? String else {
            completionHandler()
            return
        }
        guard let sessionID = response.notification.request.content.userInfo["id"] as? String else {
            completionHandler()
            return
        }
        print("Identifier: \(response.actionIdentifier)")
        if response.notification.request.content.categoryIdentifier == "PASSWORD_REQUEST" {
            if response.actionIdentifier == "ACCEPT" {
                //launchRequestView(sessionID: sessionID, siteID: siteID, sandboxed: true, accepted: true)
                notificationUserInfo = [
                    "sessionID": sessionID,
                    "siteID": siteID,
                    "accepted": "true"
                ]
            } else if response.actionIdentifier == "REJECT" {
                // Do nothing / log?
            }
        }
        
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // This should present request page --> Yes / NO. AUthentication after or before?
            //launchRequestView(sessionID: sessionID, siteID: siteID, sandboxed: true)
            print("Identifier: default")
            notificationUserInfo = [
                "sessionID": sessionID,
                "siteID": siteID,
                "accepted": "false"
            ]
        }
        completionHandler()
    }


    func application(_ application: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        // App opened with url
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
        authenticated = false
        requestInProgress = false
    }


    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo
        //notificationUserInfo = nil
        // TODO: Can we discover here if an app was launched with a remote notification and present the request view controller instead of login?
        let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "LoginController") as! LoginViewController
        self.window?.rootViewController = viewController
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
        print("applicationDidBecomeActive")
        if notificationUserInfo != nil && !requestInProgress {
            requestInProgress = true
            let info = notificationUserInfo!
            launchRequestView(sessionID: info["sessionID"]!, siteID: info["siteID"]!, sandboxed: true, accepted: info["accepted"] == "true")
            notificationUserInfo = nil
        } else if !authenticated && !requestInProgress {
            if let viewController = UIApplication.shared.visibleViewController as? LoginViewController {
                viewController.authenticateUser()
            } else {
                print("TODO: test if this can happen..: \(UIApplication.shared.visibleViewController)")
                // This means TouchID is cancelled in RequestViewController. What should happen if you do this? 
            }
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        
        // FOR TESTING PURPOSES
        //deleteSessionKeys() // Uncomment if session keys should be cleaned before startup
        //deletePasswords()   // Uncomment if passwords should be cleaned before startup
        //deleteSeed()      // Uncomment if you want to force seed regeneration
    }

    private func deleteSessionKeys() {
        // Remove passwords
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "com.keyn.session.browser"]

        // Try to delete the seed if it exists.
        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound { print("No browser sessions found") } else {
            print(status)
        }

        // Remove passwords
        let query2: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "com.keyn.session.app"]

        // Try to delete the seed if it exists.
        let status2 = SecItemDelete(query2 as CFDictionary)

        if status2 == errSecItemNotFound { print("No own sessions keys found") } else {
            print(status2)
        }
    }

    private func deletePasswords() {
        // Remove passwords
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "com.keyn.account"]

        // Try to delete the seed if it exists.
        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound { print("No generic passwords found") } else {
            print(status)
        }
    }

    private func deleteSeed() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "com.keyn.seed"]

        // Try to delete the seed if it exists.
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecItemNotFound { print("No seed found.") } else {
            print(status)
        }
    }
    
    private func launchRequestView(sessionID: String, siteID: String, sandboxed: Bool, accepted: Bool = false) {
        do {
            if let session = try Session.getSession(id: sessionID) {
                let storyboard: UIStoryboard = UIStoryboard(name: "Request", bundle: nil)
                let viewController = storyboard.instantiateViewController(withIdentifier: "PasswordRequest") as! RequestViewController
                viewController.session = session
                viewController.siteID = siteID
                viewController.sandboxed = sandboxed
                viewController.accepted = accepted
                if sandboxed {
                    UIApplication.shared.visibleViewController?.present(viewController, animated: true, completion: {
                        self.requestInProgress = false
                    })
                } else {
                    UIApplication.shared.visibleViewController?.present(viewController, animated: true, completion: nil)
                }
            } else {
                print("Received request for session that doesn't exist.")
            }
        } catch {
            print("Session could not be decoded: \(error)")
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
            viewController = storyboard.instantiateViewController(withIdentifier: "LoginController") as! LoginViewController
        }
        
        self.window?.rootViewController = viewController
        self.window?.makeKeyAndVisible()
    }

    private func fetchAWSIdentification() {
        //        let credentialsProvider = AWSStaticCredentialsProvider(accessKey: "AKIAIPSH6JLWAEOLEXDA", secretKey: "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"))
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:. EUCentral1,
                                                                identityPoolId: "eu-central-1:ed666f3c-643e-4410-8ad8-d37b08a24ff6")

        let configuration = AWSServiceConfiguration(region: .EUCentral1, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
    }

    private func registerForPushNotifications() {
        // TODO: Add if #available(iOS 10.0, *), see https://medium.com/@thabodavidnyakalloklass/ios-push-with-amazons-aws-simple-notifications-service-sns-and-swift-made-easy-51d6c79bc206
        let acceptRequestAction = UNNotificationAction(identifier: "ACCEPT",
                                                       title: "Accept",
                                                       options: .foreground)
        let rejectRequestAction = UNNotificationAction(identifier: "REJECT",
                                                       title: "Reject",
                                                       options: .destructive)
        let passwordRequestNotificationCategory = UNNotificationCategory(identifier: "PASSWORD_REQUEST",
                                                                         actions: [acceptRequestAction, rejectRequestAction],
                                                                         intentIdentifiers: [],
                                                                         options: .customDismissAction)
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([passwordRequestNotificationCategory])
        center.requestAuthorization(options: [.badge, .alert, .sound]) { (granted, error) in
            if granted {
                DispatchQueue.main.sync {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                //Do stuff if unsuccessful… Inform user that app can't be used without push notifications
            }
        }

    }

}

