/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

/*
 * Delegates all functionality to specific services.
 */
@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    static let shared: AppDelegate = {
        UIApplication.shared.delegate as! AppDelegate
    }()
    static let startupService: AppStartupService = {
        shared.services.first(where: { $0.key == .appStartup })!.value as! AppStartupService
    }()

    enum Service {
        case appStartup
        case migration
        case pushNotification
        case pasteBoard
    }

    let services: [Service: UIApplicationDelegate] = [
        .pushNotification: PushNotificationService(),
        .appStartup: AppStartupService(),
        .migration: MigrationService(),
        .pasteBoard: PasteboardService()
    ]

    override init() {
        super.init()
        (services[.appStartup] as! AppStartupService).pushNotificationService = (services[.pushNotification] as! PushNotificationService)
    }

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        clearUserData()

        for service in services.values {
            let _ = service.application?(application, didFinishLaunchingWithOptions: launchOptions)
        }

        return true
    }

    func application(_ application: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        for service in services.values {
            let _ = service.application?(application, open: url, options: options)
        }

        return true
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        for service in services.values {
            service.application?(application, didRegisterForRemoteNotificationsWithDeviceToken: deviceToken)
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        for service in services.values {
            service.application?(application, didFailToRegisterForRemoteNotificationsWithError: error)
        }
    }

    func application(_ application: UIApplication, didReceiveRemoteNotification userInfo: [AnyHashable : Any], fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void) {
        services[.pushNotification]?.application?(application, didReceiveRemoteNotification: userInfo, fetchCompletionHandler: completionHandler)
    }

    // Called as part of the transition from the background to the active state
    func applicationWillEnterForeground(_ application: UIApplication) {
        for service in services.values {
            service.applicationWillEnterForeground?(application)
        }
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        for service in services.values {
            service.applicationDidEnterBackground?(application)
        }
    }

    func applicationWillTerminate(_ application: UIApplication) {
        for service in services.values {
            service.applicationWillTerminate?(application)
        }
    }

    // MARK: - Private

    func clearUserData() {
        #if DEBUG
        // FOR TESTING PURPOSES
        //Session.deleteAll() // Uncomment if session keys should be cleaned before startup
//        Account.deleteAll()   // Uncomment if passwords should be cleaned before startup
//        try? Seed.delete()      // Uncomment if you want to force seed regeneration
//        try? Keychain.shared.delete(id: "snsDeviceEndpointArn", service: .aws) // Uncomment to delete snsDeviceEndpointArn from Keychain
//        BackupManager.shared.deleteAllKeys()
        //Questionnaire.cleanFolder()
        //UserDefaults.standard.removeObject(forKey: "hasBeenLaunchedBeforeFlag")
        #endif
    }

}
