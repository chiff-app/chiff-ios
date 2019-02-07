/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import AWSCore
import JustLog
import LocalAuthentication
import UIKit
import UserNotifications

/*
 * Code related to starting up the app in different ways.
 */
class AppStartupService: NSObject, UIApplicationDelegate {
    var deniedPushNotifications = false
    var window: UIWindow?
    var pushNotificationService: PushNotificationService!

    // Open app normally
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        enableLogging()
        fetchAWSIdentification()
        registerForPushNotifications()

        // AuthenticationGuard must be initialized first
        let _ = AuthenticationGuard.sharedInstance
        // ?
        let _: LAError? = nil

        Questionnaire.fetch()

        // Set purple line under NavigationBar
        UINavigationBar.appearance().shadowImage = UIImage(color: UIColor(rgb: 0x4932A2), size: CGSize(width: UIScreen.main.bounds.width, height: 1))

        return true
    }

    // Open app from URL (e.g. QR code)
    func application(_ application: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        do {
            try AuthenticationGuard.sharedInstance.authorizePairing(url: url) { (session, error) in
                DispatchQueue.main.async {
                    // TODO: replace with nc
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

    // TODO: Is this when user denies push notifications? Do something with it.
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // The token is not currently available.
        Logger.shared.error("Failed to register for remote notifications.", error: error as NSError, userInfo: nil)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        if deniedPushNotifications {
            exit(0)
        } else {
            let center = UNUserNotificationCenter.current()
            center.removeAllDeliveredNotifications()
        }
    }

    // MARK: - Private

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

    private func fetchAWSIdentification() {
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:. EUCentral1,
                                                                identityPoolId: "eu-central-1:7ab4f662-00ed-4a86-a03e-533c43a44dbe")

        let configuration = AWSServiceConfiguration(region: .EUCentral1, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
    }

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
        center.delegate = pushNotificationService
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
}
