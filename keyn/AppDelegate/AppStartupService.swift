/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import AWSCore

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
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let _ = Logger.shared
        
        fetchAWSIdentification()
        registerForPushNotifications()

        // AuthenticationGuard must be initialized first
        let _ = AuthenticationGuard.shared
        // Fixes some LocalAuthentication bug
        let _: LAError? = nil

        Questionnaire.fetch()

        return true
    }

    // Open app from URL (e.g. QR code)
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        do {
            try AuthorizationGuard.authorizePairing(url: url) { (session, error) in
                DispatchQueue.main.async {
                    if let session = session {
                        NotificationCenter.default.post(name: .sessionStarted, object: nil, userInfo: ["session": session])
                    } else if let error = error {
                        Logger.shared.error("Error creating session.", error: error)
                    } else {
                        Logger.shared.error("Error opening app from URL.")
                    }
                }
            }
        } catch {
            Logger.shared.error("Error creating session.", error: error)
        }

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        AWS.shared.snsRegistration(deviceToken: deviceToken)
    }

    #warning("TODO: Show an error to the user: This app cannot register for push notifications.")
    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        // The token is not currently available.
        Logger.shared.error("Failed to register for remote notifications.", error: error, userInfo: nil)
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

    private func fetchAWSIdentification() {
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:. EUCentral1,
                                                                identityPoolId: Properties.AWSIdentityPoolId)
        let configuration = AWSServiceConfiguration(region: .EUCentral1, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
    }

    private func registerForPushNotifications() {
        let passwordRequest = UNNotificationCategory(identifier: NotificationCategory.PASSWORD_REQUEST,
                                                     actions: [],
                                                     intentIdentifiers: [],
                                                     options: .customDismissAction)
        let endSession = UNNotificationCategory(identifier: NotificationCategory.END_SESSION,
                                                actions: [],
                                                intentIdentifiers: [],
                                                options: UNNotificationCategoryOptions(rawValue: 0))
        let passwordChangeConfirmation = UNNotificationCategory(identifier: NotificationCategory.CHANGE_CONFIRMATION,
                                                                actions: [],
                                                                intentIdentifiers: [],
                                                                options: UNNotificationCategoryOptions(rawValue: 0))
        let keyn = UNNotificationCategory(identifier: NotificationCategory.KEYN_NOTIFICATION,
                                          actions: [],
                                          intentIdentifiers: [],
                                          options: .customDismissAction)
        let center = UNUserNotificationCenter.current()
        center.delegate = pushNotificationService
        center.setNotificationCategories([passwordRequest, endSession, passwordChangeConfirmation, keyn])
        center.requestAuthorization(options: [.alert, .sound]) { (granted, error) in
            if granted {
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                    self.launchInitialView()
                }
            } else {
                Logger.shared.warning("User denied remote notifications.")
                self.deniedPushNotifications = true
                self.launchErrorView("errors.no_push_notifications".localized)
            }
        }
    }

    // If there is no seed in the keychain (first run or if deleteSeed() has been called,
    // a new seed will be generated and stored in the Keychain. Otherwise LoginController is launched.
    private func launchInitialView() {
        self.window = UIWindow(frame: UIScreen.main.bounds)
        let viewController: UIViewController?

        if Properties.isFirstLaunch() {
            Logger.shared.analytics("App was installed", code: .install)
            let _ = Properties.installTimestamp()
            UserDefaults.standard.addSuite(named: Questionnaire.suite)
            Questionnaire.createQuestionnaireDirectory()
            AWS.shared.isFirstLaunch = true
        }
        
        if Seed.hasKeys && BackupManager.shared.hasKeys {
            guard let vc = UIStoryboard.main.instantiateViewController(withIdentifier: "RootController") as? RootViewController else {
                Logger.shared.error("Unexpected root view controller type")
                fatalError("Unexpected root view controller type")
            }
            viewController = vc
            
        } else {
            let storyboard: UIStoryboard = UIStoryboard.get(.initialisation)
            let rootController = storyboard.instantiateViewController(withIdentifier: "InitialisationViewController")
            viewController = rootController
        }

        self.window?.rootViewController = viewController
        self.window?.makeKeyAndVisible()
    }

    private func launchErrorView(_ message: String) {
        DispatchQueue.main.async {
            self.window = UIWindow(frame: UIScreen.main.bounds)
            guard let viewController = UIStoryboard.main.instantiateViewController(withIdentifier: "ErrorViewController") as? ErrorViewController else {
                Logger.shared.error("Can't create ErrorViewController so we have no way to start the app.")
                fatalError("Can't create ErrorViewController so we have no way to start the app.")
            }

            viewController.errorMessage = message
            self.window?.rootViewController = viewController
            self.window?.makeKeyAndVisible()
        }
    }

}
