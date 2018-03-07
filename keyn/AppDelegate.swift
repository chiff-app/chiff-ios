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

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?
    var pushNotification: PushNotification?
    var requestInProgress = false
    let lockViewTag = 390847239047

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        
        // FOR TESTING PURPOSES
        //deleteSessionKeys() // Uncomment if session keys should be cleaned before startup
        //deletePasswords()   // Uncomment if passwords should be cleaned before startup
        //deleteSeed()      // Uncomment if you want to force seed regeneration
        
        // Override point for customization after application launch.
        pushNotification = nil
        fetchAWSIdentification()
        launchInitialView()
        registerForPushNotifications()
        
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
        guard let siteID = notification.request.content.userInfo["siteID"] as? String else {
            completionHandler([])
            return
        }
        guard let sessionID = notification.request.content.userInfo["sessionID"] as? String else {
            completionHandler([])
            return
        }
        guard let browserTab = notification.request.content.userInfo["browserTab"] as? Int else {
            completionHandler([])
            return
        }
        // TODO: Find out why we cannot pass RequestType in userInfo..
        guard let requestTypeValue = notification.request.content.userInfo["requestType"] as? Int, let requestType = RequestType(rawValue: requestTypeValue) else {
            completionHandler([])
            return
        }

        DispatchQueue.main.async {
            self.launchRequestView(with: PushNotification(sessionID: sessionID, siteID: siteID, browserTab: browserTab, requestType: requestType))
        }

        completionHandler([.sound])
    }

    // Called to let your app know which action was selected by the user for a given notification.
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        guard let siteID = response.notification.request.content.userInfo["siteID"] as? String else {
            completionHandler()
            return
        }
        guard let sessionID = response.notification.request.content.userInfo["sessionID"] as? String else {
            completionHandler()
            return
        }
        guard let browserTab = response.notification.request.content.userInfo["browserTab"] as? Int else {
            completionHandler()
            return
        }
        // TODO: Find out why we cannot pass RequestType in userInfo..
        guard let requestTypeValue = response.notification.request.content.userInfo["requestType"] as? Int, let requestType = RequestType(rawValue: requestTypeValue) else {
            completionHandler()
            return
        }

        print("Identifier: \(response.actionIdentifier)")

        if response.notification.request.content.categoryIdentifier == "PASSWORD_REQUEST" {
            if response.actionIdentifier == "ACCEPT" {
//                cancelAutoAuthentication()
//                notificationUserInfo = [
//                    "sessionID": sessionID,
//                    "siteID": siteID,
//                    "accepted": "true"
//                ]

                // Directly send password? Is this a security risk? Should be tested
                if let account = try! Account.get(siteID: siteID), let session = try! Session.getSession(id: sessionID) {
                    try! session.sendCredentials(account: account, browserTab: browserTab, type: requestType)
                }
            }
        }
        
        if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
            // This should present request page --> Yes / NO. AUthentication after or before?
            cancelAutoAuthentication()
            pushNotification = PushNotification(sessionID: sessionID, siteID: siteID, browserTab: browserTab, requestType: requestType)
        }

        completionHandler()
    }

    private func cancelAutoAuthentication() {
        if let viewController = self.window?.rootViewController as? LoginViewController {
            viewController.autoAuthentication = false
        } 
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
        requestInProgress = false
        if let frame = self.window?.frame {
            let lockView = UIView(frame: frame)
            let keynLogoView = UIImageView(image: UIImage(named: "logo"))
            keynLogoView.frame = CGRect(x: 138, y: 289, width: 99, height: 88)
            keynLogoView.contentMode = .scaleAspectFit
            lockView.addSubview(keynLogoView)
            lockView.backgroundColor = UIColor(rgb: 0x46319B)
            lockView.tag = lockViewTag
            self.window?.addSubview(lockView)
            self.window?.bringSubview(toFront: lockView)
        }
    }

    // Called as part of the transition from the background to the active state;
    // here you can undo notificationUserInfo = nil
    func applicationWillEnterForeground(_ application: UIApplication) {
        // TODO: Can we discover here if an app was launched with a remote notification and present the request view controller instead of login?
        let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let viewController = storyboard.instantiateViewController(withIdentifier: "LoginController") as! LoginViewController
        self.window?.rootViewController = viewController
    }

    // Restart any tasks that were paused (or not yet started) while the application was inactive.
    // If the application was previously in the background, optionally refresh the user interface.
    func applicationDidBecomeActive(_ application: UIApplication) {
        if let lockView = self.window?.viewWithTag(lockViewTag) {
            lockView.removeFromSuperview()
        }

        if pushNotification != nil && !requestInProgress {
            requestInProgress = true
            launchRequestView(with: pushNotification!)
            pushNotification = nil
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
        
        // FOR TESTING PURPOSES
        //deleteSessionKeys() // Uncomment if session keys should be cleaned before startup
        //deletePasswords()   // Uncomment if passwords should be cleaned before startup
        //deleteSeed()        // Uncomment if you want to force seed regeneration
    }

    private func launchRequestView(with notification: PushNotification) {
        do {
            if let session = try Session.getSession(id: notification.sessionID) {
                let storyboard: UIStoryboard = UIStoryboard(name: "Request", bundle: nil)
                let viewController = storyboard.instantiateViewController(withIdentifier: "PasswordRequest") as! RequestViewController

                viewController.notification = notification
                viewController.session = session

                UIApplication.shared.visibleViewController?.present(viewController, animated: true, completion: {
                    self.requestInProgress = false
                })
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

    @available(iOS 10.0, *)
    private func registerForPushNotifications() {
        // TODO: Add if #available(iOS 10.0, *), see https://medium.com/@thabodavidnyakalloklass/ios-push-with-amazons-aws-simple-notifications-service-sns-and-swift-made-easy-51d6c79bc206
        let acceptRequestAction = UNNotificationAction(identifier: "ACCEPT",
                                                       title: "Accept",
                                                       options: .authenticationRequired)
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
        center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            if granted {
                DispatchQueue.main.sync {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                // TODO: Do stuff if unsuccessful… Inform user that app can't be used without push notifications
            }
        }

    }

    // MARK: Debugging methods

    private func deleteSessionKeys() {
        // Remove passwords
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "io.keyn.session.browser"]

        // Try to delete the seed if it exists.
        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound { print("No browser sessions found") } else {
            print(status)
        }

        // Remove passwords
        let query2: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: "io.keyn.session.app"]

        // Try to delete the seed if it exists.
        let status2 = SecItemDelete(query2 as CFDictionary)

        if status2 == errSecItemNotFound { print("No own sessions keys found") } else {
            print(status2)
        }
    }

    private func deletePasswords() {
        // Remove passwords
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "io.keyn.account"]

        // Try to delete the seed if it exists.
        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound { print("No generic passwords found") } else {
            print(status)
        }
    }

    private func deleteSeed() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "io.keyn.seed"]

        // Try to delete the seed if it exists.
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecItemNotFound { print("No seed found.") } else {
            print(status)
        }
    }

}
