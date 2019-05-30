/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */

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

        // AuthenticationGuard and Logger must be initialized first
        let _ = Logger.shared
        let _ = AuthenticationGuard.shared

        Questionnaire.fetch()
        UIFixes()

        launchInitialView()

        return true
    }

    // Open app from URL (e.g. QR code)
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        AuthorizationGuard.authorizePairing(url: url, authenticationCompletionHandler: nil) { (session, error) in
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

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard Seed.hasKeys else {
            Logger.shared.warning("didRegisterForRemoteNotificationsWithDeviceToken was called with no seed present")
            return
        }
        NotificationManager.shared.snsRegistration(deviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        guard (error as NSError).code != 3010 else {
            return
        }
        launchErrorView("\("errors.push_notifications_error".localized): \(error)")
        Logger.shared.error("Failed to register for remote notifications.", error: error, userInfo: nil)
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        UNUserNotificationCenter.current().getNotificationSettings { (settings) in
            if settings.authorizationStatus == .denied {
                if !Properties.deniedPushNotifications {
                    Properties.deniedPushNotifications = true
                    NotificationCenter.default.post(name: .notificationSettingsUpdated, object: nil)
                }
            } else if settings.authorizationStatus == .authorized {
                if Properties.deniedPushNotifications {
                    Properties.deniedPushNotifications = false
                    NotificationCenter.default.post(name: .notificationSettingsUpdated, object: nil)
                }
            }
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
    }

    func registerForPushNotifications(completionHandler: @escaping (_ result: Bool) -> Void) {
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
            DispatchQueue.main.async {
                Properties.deniedPushNotifications = !granted
                if granted {
                    UIApplication.shared.registerForRemoteNotifications()
                    completionHandler(true)
                } else {
                    Logger.shared.warning("User denied remote notifications.")
                    self.deniedPushNotifications = true
                    completionHandler(false)
                }
            }
        }
    }

    // MARK: - Private

    private func launchInitialView() {
        self.window = UIWindow(frame: UIScreen.main.bounds)

        if Properties.isFirstLaunch() {
            // Purge Keychain
            Session.purgeSessionDataFromKeychain()
            Account.deleteAll()
            try? Seed.delete()
            NotificationManager.shared.deleteEndpoint()
            BackupManager.shared.deleteAllKeys()

            Logger.shared.analytics("App was installed", code: .install)
            let _ = Properties.installTimestamp()
            UserDefaults.standard.addSuite(named: Questionnaire.suite)
            Questionnaire.createQuestionnaireDirectory()
        } else if !Properties.questionnaireDirPurged {
            Questionnaire.cleanFolder()
            Properties.questionnaireDirPurged = true
            Seed.paperBackupCompleted = migratePaperbackupCompletedStatus()
        }
        guard Seed.hasKeys == BackupManager.shared.hasKeys else {
            launchErrorView("Inconsistency between seed and backup keys.")
            return
        }
        if Seed.hasKeys && BackupManager.shared.hasKeys {
            registerForPushNotifications { result in
                guard let vc = UIStoryboard.main.instantiateViewController(withIdentifier: "RootController") as? RootViewController else {
                    Logger.shared.error("Unexpected root view controller type")
                    fatalError("Unexpected root view controller type")
                }
                self.window?.rootViewController = vc
                self.window?.makeKeyAndVisible()
            }
        } else {
            let storyboard: UIStoryboard = UIStoryboard.get(.initialisation)
            self.window?.rootViewController = storyboard.instantiateViewController(withIdentifier: "InitialisationViewController")
            self.window?.makeKeyAndVisible()
        }
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

    private func UIFixes() {
        let tabBar = UITabBar.appearance()
        tabBar.barTintColor = UIColor.clear
        tabBar.backgroundImage = UIImage()
        tabBar.shadowImage = UIImage()
            UITabBarItem.appearance().setTitleTextAttributes([
            .font: UIFont(name: "Montserrat-Bold", size: 15)!,
            .foregroundColor: UIColor.primary
        ], for: .normal)
        UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .default)
        UINavigationBar.appearance().shadowImage = UIImage()
        UINavigationBar.appearance().isTranslucent = true
        UINavigationBar.appearance().backIndicatorImage = UIImage(named: "chevron_left")?.withInsets(UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10))
        UINavigationBar.appearance().backIndicatorTransitionMaskImage =  UIImage(named: "chevron_left")?.withInsets(UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10))
        UIBarButtonItem.appearance().setTitleTextAttributes([.foregroundColor: UIColor.primary,
                                                       .font: UIFont.primaryBold!], for: UIControl.State.normal)
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: UIFont.primaryBold!], for: UIControl.State.highlighted)
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: UIFont.primaryBold!], for: UIControl.State.selected)
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: UIFont.primaryBold!], for: UIControl.State.focused)
        UIBarButtonItem.appearance().setTitleTextAttributes([.foregroundColor: UIColor.primaryHalfOpacity,
                                                       .font: UIFont.primaryBold!], for: UIControl.State.disabled)
    }

    private func migratePaperbackupCompletedStatus() -> Bool {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrAccount as String: "io.keyn.seed.master",
                                    kSecAttrService as String: "io.keyn.seed",
                                    kSecMatchLimit as String: kSecMatchLimitOne,
                                    kSecReturnAttributes as String: true,
                                    kSecUseAuthenticationUI as String: kSecUseAuthenticationUISkip]

        var queryResult: AnyObject?
        let status = withUnsafeMutablePointer(to: &queryResult) {
            SecItemCopyMatching(query as CFDictionary, UnsafeMutablePointer($0))
        }

        if status == errSecItemNotFound {
            return false
        }
        guard status == noErr else {
            return false
        }

        guard let dataArray = queryResult as? [String: Any] else {
            return false
        }

        guard let label = dataArray[kSecAttrLabel as String] as? String else {
            return false
        }

        return label == "true"
    }

}   
