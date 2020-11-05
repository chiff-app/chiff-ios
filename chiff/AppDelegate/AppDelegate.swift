//
//  AppDelegate.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

/*
 * Delegates all functionality to specific services.
 */
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static let shared: AppDelegate = {
        // swiftlint:disable:next force_cast
        UIApplication.shared.delegate as! AppDelegate
    }()

    let startupService = AppStartupService()
    let notificationService = PushNotificationService()
    let pasteBoardService = PasteboardService()

    override init() {
        super.init()
        startupService.pushNotificationService = notificationService
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        clearUserData()
        _ = startupService.application(application, didFinishLaunchingWithOptions: launchOptions)
        _ = notificationService.application(application, didFinishLaunchingWithOptions: launchOptions)
        _ = pasteBoardService.application(application, didFinishLaunchingWithOptions: launchOptions)
        return true
    }

    // This only executes if the app is opened from the keyn:// scheme
    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        _ = (startupService as UIApplicationDelegate).application?(application, open: url, options: options)
        _ = (notificationService as UIApplicationDelegate).application?(application, open: url, options: options)
        _ = (pasteBoardService as UIApplicationDelegate).application?(application, open: url, options: options)
        return true
    }

    // This executes when opened from https://keyn.app/pair
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        var response = false
        if let result = (startupService as UIApplicationDelegate).application?(application, continue: userActivity, restorationHandler: restorationHandler) {
            response = response || result
        }
        if let result = (notificationService as UIApplicationDelegate).application?(application, continue: userActivity, restorationHandler: restorationHandler) {
            response = response || result
        }
        if let result = (pasteBoardService as UIApplicationDelegate).application?(application, continue: userActivity, restorationHandler: restorationHandler) {
            response = response || result
        }
        return response
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        _ = (startupService as UIApplicationDelegate).application?(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        _ = (notificationService as UIApplicationDelegate).application?(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        _ = (pasteBoardService as UIApplicationDelegate).application?(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        _ = (startupService as UIApplicationDelegate).application?(application, didFailToRegisterForRemoteNotificationsWithError: error)
        _ = (notificationService as UIApplicationDelegate).application?(application, didFailToRegisterForRemoteNotificationsWithError: error)
        _ = (pasteBoardService as UIApplicationDelegate).application?(application, didFailToRegisterForRemoteNotificationsWithError: error)
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable: Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        (notificationService as UIApplicationDelegate).application?(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
    }

    // Called as part of the transition from the background to the active state
    func applicationWillEnterForeground(_ application: UIApplication) {
        _ = (startupService as UIApplicationDelegate).applicationWillEnterForeground?(application)
        _ = (notificationService as UIApplicationDelegate).applicationWillEnterForeground?(application)
        _ = (pasteBoardService as UIApplicationDelegate).applicationWillEnterForeground?(application)
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        _ = (startupService as UIApplicationDelegate).applicationDidEnterBackground?(application)
        _ = (notificationService as UIApplicationDelegate).applicationDidEnterBackground?(application)
        _ = (pasteBoardService as UIApplicationDelegate).applicationDidEnterBackground?(application)
    }

    func applicationWillTerminate(_ application: UIApplication) {
        _ = (startupService as UIApplicationDelegate).applicationWillTerminate?(application)
        _ = (notificationService as UIApplicationDelegate).applicationWillTerminate?(application)
        _ = (pasteBoardService as UIApplicationDelegate).applicationWillTerminate?(application)
    }

    // MARK: - Private

    func clearUserData() {
        #if DEBUG
        // FOR TESTING PURPOSES
        //TeamSession.deleteAll() // Uncomment if session keys should be cleaned before startup
        //UserAccount.deleteAll()   // Uncomment if passwords should be cleaned before startup
        //try? Seed.delete()      // Uncomment if you want to force seed regeneration
        //try? Keychain.shared.delete(id: "snsDeviceEndpointArn", service: "io.keyn.aws") // Uncomment to delete snsDeviceEndpointArn from Keychain
        //Keychain.shared.deleteAll(service: TeamSession.encryptionService)
        //Keychain.shared.deleteAll(service: TeamSession.signingService)
        //NotificationManager.shared.deleteKeys()
        //BackupManager.deleteAll()
        //UserDefaults.standard.removeObject(forKey: "hasBeenLaunchedBeforeFlag")
        #endif
    }

}
