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
import LocalAuthentication
import JustLog
import CocoaAsyncSocket

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
        //Questionnaire.cleanFolder()

        // Override point for customization after application launch.
        enableLogging()
        fetchAWSIdentification()
        registerForPushNotifications()

        let _ = AuthenticationGuard.sharedInstance
        let _: LAError? = nil

        let nc = NotificationCenter.default
        nc.addObserver(forName: NSNotification.Name.UIPasteboardChanged, object: nil, queue: nil, using: handlePasteboardChangeNotification)
        nc.addObserver(forName: NSNotification.Name.passwordChangeConfirmation, object: nil, queue: nil, using: handlePasswordConfirmationNotification)
        
        // Set purple line under NavigationBar
        UINavigationBar.appearance().shadowImage = UIImage(color: UIColor(rgb: 0x4932A2), size: CGSize(width: UIScreen.main.bounds.width, height: 1))

        UserDefaults.standard.removeObject(forKey: "backedUp")

        Questionnaire.fetch()
        handlePendingNotifications()
        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AWS.sharedInstance.snsRegistration(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // The token is not currently available.
        Logger.shared.error("Failed to register for remote notifications.", error: error as NSError, userInfo: nil)
        // TODO: disable stuff. App shouldn't work without remote notifications.
    }
    
    // Called when a notification is delivered to a foreground app.
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        // TODO: Find out why we cannot pass RequestType in userInfo..
        guard notification.request.content.categoryIdentifier != "KEYN_NOTIFICATION" else {
            Logger.shared.debug("TODO: Make alert banner")
            completionHandler([.alert])
            return
        }
        
        // DEBUG: Push notifications
        var originalBody: String?
        var content: UNNotificationContent
        var reprocessed = false
        var error: String?
        if notification.request.content.userInfo["requestType"] != nil {
            content = notification.request.content
            error = content.userInfo["error"] as? String
        } else {
            originalBody = notification.request.content.body
            content = reprocess(content: notification.request.content)
            error = content.userInfo["error"] as? String
            reprocessed = true
        }
        Logger.shared.debug("PushNotificationDebug", userInfo: [
            "body": content.body,
            "reprocessed": reprocessed,
            "error": error,
            "originalBody": originalBody
        ])
        
        guard let browserMessageTypeValue = content.userInfo["requestType"] as? Int, let browserMessageType = BrowserMessageType(rawValue: browserMessageTypeValue) else {
            Logger.shared.warning("Could not parse browsermessage.")
            completionHandler([])
            return
        }

        guard let sessionID = content.userInfo["sessionID"] as? String else {
            Logger.shared.warning("Could not parse sessionID.")
            completionHandler([])
            return
        }
        if browserMessageType == .end {
            do {
                try Session.getSession(id: sessionID)?.delete(includingQueue: false)
                if let rootViewController = window?.rootViewController as? RootViewController, let devicesNavigationController = rootViewController.viewControllers?[1] as? DevicesNavigationController {
                    for viewController in devicesNavigationController.viewControllers {
                        if let devicesViewController = viewController as? DevicesViewController {
                            if devicesViewController.isViewLoaded {
                                devicesViewController.removeSessionFromTableView(sessionID: sessionID)
                            }
                        }
                    }
                }
            } catch {
                Logger.shared.error("Could not end session.", error: error as NSError, userInfo: nil)
            }
            completionHandler([.alert, .sound])
        } else {
            if handleNotification(userInfo: content.userInfo, sessionID: sessionID, browserMessageType: browserMessageType) {
                completionHandler([.sound])
            } else {
                completionHandler([])
            }
        }
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any]) {
        Logger.shared.debug("PushNotificationDebug", userInfo: ["title": userInfo["requestType"] ?? "nada"])
    }
    
    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        Logger.shared.debug("PushNotificationDebug", userInfo: ["title": userInfo["requestType"] ?? "nada"])

        guard let browserMessageTypeValue = userInfo["requestType"] as? Int, let browserMessageType = BrowserMessageType(rawValue: browserMessageTypeValue) else {
            Logger.shared.warning("Could not parse browsermessage.")
            completionHandler(UIBackgroundFetchResult.noData)
            return
        }
        
        guard let sessionID = userInfo["sessionID"] as? String else {
            Logger.shared.warning("Could not parse sessionID.")
            completionHandler(UIBackgroundFetchResult.noData)
            return
        }
        
        if browserMessageType == .end {
            do {
                try Session.getSession(id: sessionID)?.delete(includingQueue: false)
            } catch {
                Logger.shared.error("Could not end session.", error: error as NSError, userInfo: nil)
            }
        } else {
            let _ = handleNotification(userInfo: userInfo, sessionID: sessionID, browserMessageType: browserMessageType)
        }
        completionHandler(UIBackgroundFetchResult.noData)
    }

    // Called to let your app know which action was selected by the user for a given notification.
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        // TODO: Find out why we cannot pass RequestType in userInfo..

        guard response.notification.request.content.categoryIdentifier != "KEYN_NOTIFICATION" else {
            Logger.shared.debug("TODO: Make alert banner")
            completionHandler()
            return
        }
        
        // DEBUG: Push notifications
        var originalBody: String?
        var content: UNNotificationContent
        var reprocessed = false
        var error: String?
        if response.notification.request.content.userInfo["requestType"] != nil {
            content = response.notification.request.content
            error = content.userInfo["error"] as? String
        } else {
            originalBody = response.notification.request.content.body
            content = reprocess(content: response.notification.request.content)
            error = content.userInfo["error"] as? String
            reprocessed = true
        }
        Logger.shared.debug("PushNotificationDebug", userInfo: [
            "body": content.body,
            "reprocessed": reprocessed,
            "error": error,
            "originalBody": originalBody
        ])
        
        
        
        guard let browserMessageTypeValue = content.userInfo["requestType"] as? Int, let browserMessageType = BrowserMessageType(rawValue: browserMessageTypeValue) else {
            Logger.shared.warning("Could not parse browsermessage.")
            completionHandler()
            return
        }

        guard let sessionID = content.userInfo["sessionID"] as? String else {
            Logger.shared.warning("Could not parse sessionID.")
            completionHandler()
            return
        }

        if browserMessageType == .end {
            do {
                try Session.getSession(id: sessionID)?.delete(includingQueue: false)
            } catch {
                Logger.shared.error("Could not end session.", error: error as NSError, userInfo: nil)
            }
        } else {
            let _ = handleNotification(userInfo: content.userInfo, sessionID: sessionID, browserMessageType: browserMessageType)
        }
        completionHandler()
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
        // Clean up notifications
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
    }


    // Called as part of the transition from the background to the active state;
    // here you can undo notificationUserInfo = nil
    func applicationWillEnterForeground(_ application: UIApplication) {
        handlePendingNotifications()
    }


    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }
    
    // Called when app starts up. Short polling
    private func checkPendingChangeConfirmations() {
        do {
            if let sessions = try Session.all() {
                for session in sessions {
                    self.pollQueue(attempts: 1, session: session, shortPolling: true, completionHandler: nil)
                }
            }
        } catch {
            Logger.shared.error("Could not get sessions.", error: error as NSError)
        }
    }
    
    // Called from notification
    func handlePasswordConfirmationNotification(notification: Notification) {
        Logger.shared.debug("Started polling")
        guard let session = notification.object as? Session else {
            Logger.shared.warning("Could not parse Session object.")
            return
        }
        
        guard session.backgroundTask == UIBackgroundTaskInvalid else {
            Logger.shared.debug("Already polling")
            return
        }
        
        session.backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            Logger.shared.debug("Background task expired")
            UIApplication.shared.endBackgroundTask(session.backgroundTask)
            session.backgroundTask = UIBackgroundTaskInvalid
        })
        
        self.pollQueue(attempts: 3, session: session, shortPolling: false, completionHandler: {
            if session.backgroundTask != UIBackgroundTaskInvalid {
                Logger.shared.debug("Background task ended because polling ended")
                UIApplication.shared.endBackgroundTask(session.backgroundTask)
            } else {
                Logger.shared.debug("Background task was invalid when polling ended")
            }
        })
    }
    
    
    private func pollQueue(attempts: Int, session: Session, shortPolling: Bool, completionHandler: (() -> Void)?) {
        AWS.sharedInstance.getFromSqs(from: session.sqsControlQueue, shortPolling: shortPolling) { (messages, queueName) in
            if messages.count > 0 {
                for message in messages {
                    guard let body = message.body else {
                        Logger.shared.error("Could not parse SQS message body.")
                        return
                    }
                    guard let receiptHandle = message.receiptHandle else {
                        Logger.shared.error("Could not parse SQS message body.")
                        return
                    }
                    guard let typeString = message.messageAttributes?["type"]?.stringValue, let type = Int(typeString) else {
                        Logger.shared.error("Could not parse SQS message body.")
                        return
                    }
                    guard type == BrowserMessageType.acknowledge.rawValue else {
                        Logger.shared.error("Wrong message type.", userInfo: ["type": type])
                        return
                    }
                    AWS.sharedInstance.deleteFromSqs(receiptHandle: receiptHandle, queueName: queueName)

                    do {
                        let browserMessage: BrowserMessage = try session.decrypt(message: body)
                        if let result = browserMessage.v, let accountId = browserMessage.a, browserMessage.r == .acknowledge, result {
                            var account = try Account.get(accountID: accountId)
                            try account?.updatePassword(offset: nil)
                        }
                    } catch {
                        Logger.shared.warning("Could not change password", error: error as NSError, userInfo: nil)
                    }
                    if let handler = completionHandler {
                        handler()
                    }
                }
            } else {
                if (attempts > 1) {
                    self.pollQueue(attempts: attempts - 1, session: session, shortPolling: shortPolling, completionHandler: completionHandler)
                } else if let handler = completionHandler {
                    handler()
                }
            }
        }
    }
    
    
    private func handlePasteboardChangeNotification(notification: Notification) {
        let pasteboard = UIPasteboard.general
        guard let text = pasteboard.string, text != "" else {
            return
        }
        
        let pasteboardVersion = pasteboard.changeCount
        let clearPasteboardTimeout = 60.0 // TODO: hardcoded for now. This should be editable in settings I guess?
        
        var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskInvalid
        backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = UIBackgroundTaskInvalid
        })
        
        DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + clearPasteboardTimeout) {
            if pasteboardVersion == pasteboard.changeCount {
                pasteboard.string = ""
            }
            
            if backgroundTask != UIBackgroundTaskInvalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
            }
        }
    }
    
    private func handleNotification(userInfo: [AnyHashable: Any], sessionID: String, browserMessageType: BrowserMessageType) -> Bool {
        guard let siteID = userInfo["siteID"] as? String else {
            Logger.shared.warning("Wrong siteID type.")
            return false
        }
        guard let siteName = userInfo["siteName"] as? String else {
            Logger.shared.warning("Wrong siteName type.")
            return false
        }
        guard let browserTab = userInfo["browserTab"] as? Int else {
            Logger.shared.warning("Wrong browserTab type.")
            return false
        }
        guard let currentPassword = userInfo["password"] as? String? else {
            Logger.shared.warning("Wrong currentPassword type.")
            return false
        }
        guard let username = userInfo["username"] as? String? else {
            Logger.shared.warning("Wrong username type.")
            return false
        }
        
        // TODO: Should probably be removed since password confirmations are now managed by SQS queue.
        if browserMessageType == .acknowledge {
            guard let shouldChangePassword = userInfo["changeValue"] as? Bool else {
                Logger.shared.warning("Wrong shouldChangePassword type.")
                return false
            }
            
            if shouldChangePassword {
                var account = try! Account.get(siteID: siteID)[0] // TODO: probably should send or save accountID somewhere instead of siteID
                try! account.updatePassword(offset: nil)
            }
            return false
        } else {
            AuthenticationGuard.sharedInstance.launchRequestView(with: PushNotification(sessionID: sessionID, siteID: siteID, siteName: siteName, browserTab: browserTab, currentPassword: currentPassword, requestType: browserMessageType, username: username))
        }
        return true
    }
    
    // DEBUG
    private func reprocess(content: UNNotificationContent) -> UNNotificationContent {
        guard let mutableContent = (content.mutableCopy() as? UNMutableNotificationContent) else {
            return content
        }
        do {
            let processor = NotificationProcessor()
            return try processor.process(content: mutableContent)
        } catch {
            Logger.shared.debug("Reprocessing error", error: error as NSError)
        }
        return content
    }

    private func handlePendingNotifications() {
        checkPendingChangeConfirmations()
        let center = UNUserNotificationCenter.current()
        center.getDeliveredNotifications { (notifications) in
            for notification in notifications {
                
                guard notification.request.content.categoryIdentifier != "KEYN_NOTIFICATION" else {
                    Logger.shared.debug("TODO: Make alert banner")
                    return
                }
                
                // DEBUG: Push notifications
                var originalBody: String?
                var content: UNNotificationContent
                var reprocessed = false
                var error: String?
                if notification.request.content.userInfo["requestType"] != nil {
                    content = notification.request.content
                    error = content.userInfo["error"] as? String
                } else {
                    originalBody = notification.request.content.body
                    content = self.reprocess(content: notification.request.content)
                    error = content.userInfo["error"] as? String
                    reprocessed = true
                }
                Logger.shared.debug("PushNotificationDebug", userInfo: [
                    "body": content.body,
                    "reprocessed": reprocessed,
                    "error": error,
                    "originalBody": originalBody
                ])
                
                
                
                if let browserMessageTypeValue = content.userInfo["requestType"] as? Int,
                    let browserMessageType = BrowserMessageType(rawValue: browserMessageTypeValue),
                    let sessionID = content.userInfo["sessionID"] as? String
                {
                    if browserMessageType == .end {
                        do {
                            try Session.getSession(id: sessionID)?.delete(includingQueue: false)
                        } catch {
                            Logger.shared.error("Could not end session.", error: error as NSError)
                        }
                        
                    } else if notification.date.timeIntervalSinceNow > -180.0  {
                        
                        if content.title == "Error" {
                            Logger.shared.warning("iOS notification content parsing failed")
                        }
                        
                        guard let siteID = content.userInfo["siteID"] as? String else {
                            Logger.shared.warning("Wrong siteID type.")
                            return
                        }
                        guard let siteName = content.userInfo["siteName"] as? String else {
                            Logger.shared.warning("Wrong siteName type.")
                            return
                        }
                        guard let browserTab = content.userInfo["browserTab"] as? Int else {
                            Logger.shared.warning("Wrong browserTab type.")
                            return
                        }
                        guard let currentPassword = content.userInfo["password"] as? String? else {
                            Logger.shared.warning("Wrong currentPassword type.")
                            return
                        }
                        guard let username = content.userInfo["username"] as? String? else {
                            Logger.shared.warning("Wrong username type.")
                            return
                        }
                        
                        DispatchQueue.main.async {
                            if !AuthenticationGuard.sharedInstance.authorizationInProgress {
                                AuthenticationGuard.sharedInstance.launchRequestView(with: PushNotification(sessionID: sessionID, siteID: siteID, siteName: siteName, browserTab: browserTab, currentPassword: currentPassword, requestType: browserMessageType, username: username))
                            }
                        }
                    }
                }
            }
        }
    }
    
    private func launchInitialView() {
        // If there is no seed in the keychain (first run or if deleteSeed() has been called, a new seed will be generated and stored in the Keychain. Otherwise LoginController is launched.
        self.window = UIWindow(frame: UIScreen.main.bounds)
        let viewController: UIViewController?
        
        if Properties.isFirstLaunch() {
            Logger.shared.info("App was installed", userInfo: ["code": AnalyticsMessage.install.rawValue])
            _ = Properties.installTimestamp()
            UserDefaults.standard.addSuite(named: Questionnaire.suite)
            Questionnaire.createQuestionnaireDirectory()
        }
        
        if !Seed.exists() {
            let storyboard: UIStoryboard = UIStoryboard(name: "Initialisation", bundle: nil)
            let rootController = storyboard.instantiateViewController(withIdentifier: "InitialisationViewController")
            viewController = rootController
        } else {
            let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
            guard let vc = storyboard.instantiateViewController(withIdentifier: "RootController") as? RootViewController else {
                Logger.shared.error("Unexpected root view controller type")
                fatalError("Unexpected root view controller type")
            }
            viewController = vc

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
    
    private func enableLogging() {
        let logger = Logger.shared
        
        // Disable file logging
        logger.enableFileLogging = false
        
        // logstash destination
        logger.logstashHost = "analytics.keyn.io"
        logger.logstashPort = 5000
        logger.logstashTimeout = 5
        logger.logLogstashSocketActivity = Properties.isDebug
        
        // default info
        logger.defaultUserInfo = ["device": "APP",
                                  "userID": Properties.userID(),
                                  "debug": Properties.isDebug]
        logger.setup()
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
        let keynNotificationCategory = UNNotificationCategory(identifier: "KEYN_NOTIFICATION",
                                                                         actions: [],
                                                                         intentIdentifiers: [],
                                                                         options: .customDismissAction)
        let endSessionNotificationCategory = UNNotificationCategory(identifier: "END_SESSION",
                                                                    actions: [],
                                                                    intentIdentifiers: [],
                                                                    options: UNNotificationCategoryOptions(rawValue: 0))
        let changeConfirmationNotificationCategory = UNNotificationCategory(identifier: "CHANGE_CONFIRMATION",
                                                                    actions: [],
                                                                    intentIdentifiers: [],
                                                                    options: UNNotificationCategoryOptions(rawValue: 0))
        let center = UNUserNotificationCenter.current()
        center.delegate = self
        center.setNotificationCategories([passwordRequestNotificationCategory, endSessionNotificationCategory, changeConfirmationNotificationCategory, keynNotificationCategory])
        center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            if granted {
                DispatchQueue.main.sync {
                    UIApplication.shared.registerForRemoteNotifications()
                    self.launchInitialView()
                }
            } else {
                Logger.shared.warning("User denied remote notifications.")
            }
        }

    }

}
