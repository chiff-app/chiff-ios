/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import AWSCore
import UserNotifications
import LocalAuthentication
import JustLog
import CocoaAsyncSocket

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    var window: UIWindow?
    var deniedPushNotifications = false

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // FOR TESTING PURPOSES
        //Session.deleteAll() // Uncomment if session keys should be cleaned before startup
        //Account.deleteAll()   // Uncomment if passwords should be cleaned before startup
        //try? Seed.delete()      // Uncomment if you want to force seed regeneration
        //try? Keychain.sharedInstance.delete(id: "snsDeviceEndpointArn", service: "io.keyn.aws") // Uncomment to delete snsDeviceEndpointArn from Keychain
        //BackupManager.sharedInstance.deleteAll()
        //Questionnaire.cleanFolder()
        //UserDefaults.standard.removeObject(forKey: "hasBeenLaunchedBeforeFlag")

        // Override point for customization after application launch.
        enableLogging()
        detectOldAccounts()
        fetchAWSIdentification()
        registerForPushNotifications()

        let _ = AuthenticationGuard.sharedInstance
        let _: LAError? = nil

        let nc = NotificationCenter.default
        nc.addObserver(forName: NSNotification.Name.UIPasteboardChanged, object: nil, queue: nil, using: handlePasteboardChangeNotification)
        nc.addObserver(forName: NSNotification.Name.passwordChangeConfirmation, object: nil, queue: nil, using: handlePasswordConfirmationNotification)
        
        // Set purple line under NavigationBar
        UINavigationBar.appearance().shadowImage = UIImage(color: UIColor(rgb: 0x4932A2), size: CGSize(width: UIScreen.main.bounds.width, height: 1))

        Questionnaire.fetch()
        handlePendingNotifications()
        
        return true
    }
    
    // Temporary for Alpha --> Beta migration. Resets Keyn if undecodable accounts or sites are found, migrates to new Keychain otherwise.
    func detectOldAccounts() {
        if !UserDefaults.standard.bool(forKey: "hasCheckedAlphaAccounts") {
            do {
                let accounts = try Account.all()
                for account in accounts {
                    try account.updateKeychainClassification()
                }
                Logger.shared.info("Updated \(accounts.count) accounts", userInfo: ["code": AnalyticsMessage.accountMigration.rawValue])
            } catch _ as DecodingError {
                Account.deleteAll()
                try? Seed.delete()
                Logger.shared.info("Removed alpha accounts", userInfo: ["code": AnalyticsMessage.accountMigration.rawValue])
            } catch {
                Logger.shared.warning("Non-decoding error with getting accounts", error: error as NSError, userInfo: ["code": AnalyticsMessage.accountMigration.rawValue])
            }
            UserDefaults.standard.set(true, forKey: "hasCheckedAlphaAccounts")
        }
        if (!UserDefaults.standard.bool(forKey: "hasCleanedSessions")) {
            Session.deleteAll()
            UserDefaults.standard.set(true, forKey: "hasCleanedSessions")
        }
    }
    
    func application(_ application: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        do {
            try AuthenticationGuard.sharedInstance.authorizePairing(url: url) { (session, error) in
                DispatchQueue.main.async {
                    if let session = session, let rootViewController = self.window?.rootViewController as? RootViewController, let devicesNavigationController = rootViewController.viewControllers?[1] as? DevicesNavigationController {
                        for viewController in devicesNavigationController.viewControllers {
                            if let devicesViewController = viewController as? DevicesViewController {
                                if devicesViewController.isViewLoaded {
                                    devicesViewController.addSession(session: session)
                                }
                            } else if let pairViewController = viewController as? PairViewController {
                                if pairViewController.isViewLoaded {
                                    pairViewController.add(session: session)
                                }
                            }
                        }
                    } else if let error = error {
                        Logger.shared.warning("Error creating session", error: error as NSError)
                    }
                }
            }
        } catch {
            Logger.shared.error("Error creating session", error: error as NSError)
        }

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AWS.sharedInstance.snsRegistration(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // The token is not currently available.
        Logger.shared.error("Failed to register for remote notifications.", error: error as NSError, userInfo: nil)
    }
    
    // Called when a notification is delivered to a foreground app.
    @available(iOS 10.0, *)
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
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
        var userInfo: [String: Any] = [
            "body": content.body,
            "reprocessed": reprocessed
        ]
        if let error = error {
            userInfo["error"] = error
        }
        if let originalBody = originalBody {
            userInfo["originalBody"] = originalBody
        }
        Logger.shared.debug("PushNotificationDebug", userInfo: userInfo)
        
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
        var userInfo: [String: Any] = [
            "body": content.body,
            "reprocessed": reprocessed
        ]
        if let error = error {
            userInfo["error"] = error
        }
        if let originalBody = originalBody {
            userInfo["originalBody"] = originalBody
        }
        Logger.shared.debug("PushNotificationDebug", userInfo: userInfo)
        
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


    // Use this method to release shared resources, save user data, invalidate timers,
    // and store enough application state information to restore your application to its
    // current state in case it is terminated later.
    // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    func applicationDidEnterBackground(_ application: UIApplication) {
        // Clean up notifications or exit if user denied push notifications.
        if deniedPushNotifications {
            exit(0)
        } else {
            let center = UNUserNotificationCenter.current()
            center.removeAllDeliveredNotifications()
        }
    }


    // Called as part of the transition from the background to the active state;
    // here you can undo notificationUserInfo = nil
    func applicationWillEnterForeground(_ application: UIApplication) {
        handlePendingNotifications()
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
        guard let session = notification.object as? Session else {
            return
        }
        
        guard session.backgroundTask == UIBackgroundTaskInvalid else {
            return
        }
        
        session.backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            UIApplication.shared.endBackgroundTask(session.backgroundTask)
            session.backgroundTask = UIBackgroundTaskInvalid
        })
        
        self.pollQueue(attempts: 3, session: session, shortPolling: false, completionHandler: {
            if session.backgroundTask != UIBackgroundTaskInvalid {
                UIApplication.shared.endBackgroundTask(session.backgroundTask)
            }
        })
    }
    
    
    private func pollQueue(attempts: Int, session: Session, shortPolling: Bool, completionHandler: (() -> Void)?) {
        do {
            try session.getChangeConfirmations(shortPolling: shortPolling) { (data) in
                if let data = data, let messages = data["messages"] as? [[String:String]], messages.count > 0 {
                    for message in messages {
                        guard let body = message["body"] else {
                            Logger.shared.error("Could not parse SQS message body.")
                            return
                        }
                        guard let receiptHandle = message["receiptHandle"] else {
                            Logger.shared.error("Could not parse SQS message body.")
                            return
                        }
                        guard let typeString = message["type"], let type = Int(typeString) else {
                            Logger.shared.error("Could not parse SQS message body.")
                            return
                        }
                        guard type == BrowserMessageType.acknowledge.rawValue else {
                            Logger.shared.error("Wrong message type.", userInfo: ["type": type])
                            return
                        }
                        session.deleteChangeConfirmation(receiptHandle: receiptHandle)
                        
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
        } catch {
            Logger.shared.error("Error getting change confirmations")
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
        
        AuthenticationGuard.sharedInstance.launchRequestView(with: PushNotification(sessionID: sessionID, siteID: siteID, siteName: siteName, browserTab: browserTab, currentPassword: currentPassword, requestType: browserMessageType, username: username))
        
        return true
    }
    
    // DEBUG
    private func reprocess(content: UNNotificationContent) -> UNNotificationContent {
        guard let mutableContent = (content.mutableCopy() as? UNMutableNotificationContent) else {
            return content
        }
        do {
            return try NotificationProcessor.process(content: mutableContent)
        } catch NotificationExtensionError.Decryption {
            Logger.shared.debug("Decryption error")
        } catch NotificationExtensionError.Session {
            Logger.shared.debug("Session error")
        } catch NotificationExtensionError.StringCast(let type) {
            Logger.shared.debug("Stringcast error: \(type)")
        } catch {
            Logger.shared.debug("Other error", error: error as NSError)
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
                var userInfo: [String: Any] = [
                    "body": content.body,
                    "reprocessed": reprocessed
                ]
                if let error = error {
                    userInfo["error"] = error
                }
                if let originalBody = originalBody {
                    userInfo["originalBody"] = originalBody
                }
                Logger.shared.debug("PushNotificationDebug", userInfo: userInfo)
                
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
            AWS.sharedInstance.isFirstLaunch = true
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
        logger.logstashHost = "listener.logz.io"
        logger.logstashPort = 5052
        logger.logzioToken = "AZQteKGtxvKchdLHLomWvbIpELYAWVHB"
        logger.logstashTimeout = 5
        logger.logLogstashSocketActivity = Properties.isDebug
        
        // default info
        logger.defaultUserInfo = [
            "app": "Keyn",
            "device": "APP",
            "userID": Properties.userID(),
            "debug": Properties.isDebug]
        logger.setup()
    }
    
    @available(iOS 10.0, *)
    private func registerForPushNotifications() {
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
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    self.launchInitialView()
                }
            } else {
                Logger.shared.warning("User denied remote notifications.")
                self.deniedPushNotifications = true
                DispatchQueue.main.async {
                    self.window = UIWindow(frame: UIScreen.main.bounds)
                    let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                    self.window?.rootViewController = storyboard.instantiateViewController(withIdentifier: "ErrorViewController")
                    self.window?.makeKeyAndVisible()
                }
            }
        }
    }
}
