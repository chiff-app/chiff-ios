//
//  AppStartupService.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import UIKit
import UserNotifications
import PromiseKit
import ChiffCore

/*
 * Code related to starting up the app in different ways.
 */
class AppStartupService: NSObject, UIApplicationDelegate {

    var window: UIWindow?
    var pushNotificationService: PushNotificationService!
    var openedFromUrl: Bool = false

    // Open app normally
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        // AuthenticationGuard and Logger must be initialized first
        ChiffCore.initialize(logger: ChiffLogger(), localizer: ChiffLocalizer())
        _ = AuthenticationGuard.shared

        UIFixes()

        launchInitialView()
        Properties.isJailbroken = isJailbroken()

        // Start listening for password change notifications
        QueueHandler.shared.start()

        return true
    }

    func application(_ application: UIApplication,
                     open url: URL,
                     options: [UIApplication.OpenURLOptionsKey: Any] = [:] ) -> Bool {
        guard url.chiffType == .otp else {
            return false
        }
        AuthenticationGuard.shared.otpUrl = url
        return true
    }

    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        guard userActivity.activityType == NSUserActivityTypeBrowsingWeb,
            let url = userActivity.webpageURL,
            let scheme = url.scheme,
            let host = url.host,
            (host == "keyn.app" || host == "chiff.app"),
            scheme == "https",
            url.path == "/pair",
            let params = url.queryParameters,
            params.count == 4,
            params.keys.contains("p"),
            params.keys.contains("q"),
            params.keys.contains("o"),
            params.keys.contains("b") else {
                // o and b are validated in authorizepairing, p and q are validated by libsodium
                return false
        }
        if let rootController = self.window?.rootViewController as? RootViewController {
            rootController.selectedIndex = 1
        } else {
            openedFromUrl = true
        }

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        guard Seed.hasKeys else {
            return
        }
        NotificationManager.shared.registerDevice(token: deviceToken)
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
                    NotificationCenter.default.postMain(name: .notificationSettingsUpdated, object: nil)
                }
            } else if settings.authorizationStatus == .authorized {
                if Properties.deniedPushNotifications {
                    Properties.deniedPushNotifications = false
                    NotificationCenter.default.postMain(name: .notificationSettingsUpdated, object: nil)
                }
            }
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        let center = UNUserNotificationCenter.current()
        center.removeAllDeliveredNotifications()
    }

    // MARK: - Private

    private func launchInitialView() {
        self.window = UIWindow(frame: UIScreen.main.bounds)

        if Properties.isFirstLaunch {
            // Purge Keychain
            BrowserSession.purgeSessionDataFromKeychain()
            TeamSession.purgeSessionDataFromKeychain()
            UserAccount.deleteAll()
            SSHIdentity.deleteAll()
            Properties.currentKeychainVersion = Properties.latestKeychainVersion
            firstly {
                NotificationManager.shared.unregisterDevice()
            }.done {
                Seed.delete(includeSeed: true)
                Logger.shared.analytics(.appFirstOpened, properties: [.timestamp: Properties.firstLaunchTimestamp ], override: true)
            }.catchLog("Failed to purge keychain on launch")
        }
        if Seed.hasKeys {
            Properties.migrateToAppGroup()
            firstly {
                Properties.deniedPushNotifications ? .value(()) : PushNotifications.register().asVoid()
            }.done(on: .main) { _ in
                self.launchRootViewController()
            }.catchLog("Failed to initialize")
        } else {
            let storyboard: UIStoryboard = UIStoryboard.get(.initialisation)
            self.window?.rootViewController = storyboard.instantiateViewController(withIdentifier: "InitialisationViewController")
            self.window?.makeKeyAndVisible()
        }
    }

    private func launchRootViewController() {
        guard let rootController = UIStoryboard.main.instantiateViewController(withIdentifier: "RootController") as? RootViewController else {
            Logger.shared.error("Unexpected root view controller type")
            fatalError("Unexpected root view controller type")
        }

        // We just open the devices tab instead of accounts when opened from a pairing url.
        if self.openedFromUrl {
            rootController.selectedIndex = 1
            self.openedFromUrl = false
        }
        self.window?.rootViewController = rootController
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

    func isJailbroken() -> Bool {
        if TARGET_IPHONE_SIMULATOR != 1 {
            // Check 1 : existence of files that are common for jailbroken devices
            if FileManager.default.fileExists(atPath: "/Applications/Cydia.app")
                || FileManager.default.fileExists(atPath: "/Library/MobileSubstrate/MobileSubstrate.dylib")
                || FileManager.default.fileExists(atPath: "/bin/bash")
                || FileManager.default.fileExists(atPath: "/usr/sbin/sshd")
                || FileManager.default.fileExists(atPath: "/etc/apt")
                || FileManager.default.fileExists(atPath: "/private/var/lib/apt/")
                || UIApplication.shared.canOpenURL(URL(string: "cydia://package/com.example.package")!) {
                return true
            }
        }

        // Check 2 : Reading and writing in system directories (sandbox violation)
        let stringToWrite = "Jailbreak Test"
        do {
            try stringToWrite.write(toFile: "/private/JailbreakTest.txt", atomically: true, encoding: String.Encoding.utf8)
            // Device is jailbroken
            return true
        } catch {
            return false
        }
    }

}
