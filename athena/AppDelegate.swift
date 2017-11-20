
//
//  AppDelegate.swift
//  athena
//
//  Created by bas on 29/09/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import UIKit

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate {

    var window: UIWindow?


    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.a

        // FOR TESTING PURPOSES
        deleteSessionKeys() // Uncomment if session keys shouldn't be cleaned before startup
        deletePasswords()   // Uncomment if passwords shouldn't be cleaned before startup
        //deleteSeed()      // Uncomment if you want to force seed regeneration

        // If there is no seed in the keychain (first run or if deleteSeed() has been called, a new seed will be generated and stored in the Keychain.
        if !Keychain.hasSeed() { try! Crypto.generateSeed() }

        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplicationOpenURLOptionsKey : Any] = [:]) -> Bool {
        // App opened with url
        // TODO: Add session persistently and do other stuff
        print(url.queryParameters)
        return true
    }

    func applicationWillResignActive(_ application: UIApplication) {
        // Sent when the application is about to move from active to inactive state. This can occur for certain types of temporary interruptions (such as an incoming phone call or SMS message) or when the user quits the application and it begins the transition to the background state.
        // Use this method to pause ongoing tasks, disable timers, and invalidate graphics rendering callbacks. Games should use this method to pause the game.
    }

    func applicationDidEnterBackground(_ application: UIApplication) {
        // Use this method to release shared resources, save user data, invalidate timers, and store enough application state information to restore your application to its current state in case it is terminated later.
        // If your application supports background execution, this method is called instead of applicationWillTerminate: when the user quits.
    }

    func applicationWillEnterForeground(_ application: UIApplication) {
        // Called as part of the transition from the background to the active state; here you can undo many of the changes made on entering the background.
    }

    func applicationDidBecomeActive(_ application: UIApplication) {
        // Restart any tasks that were paused (or not yet started) while the application was inactive. If the application was previously in the background, optionally refresh the user interface.
    }

    func applicationWillTerminate(_ application: UIApplication) {
        // Called when the application is about to terminate. Save data if appropriate. See also applicationDidEnterBackground:.
    }

    private func deleteSessionKeys() {
        // Remove session keys
        let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom]

        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound { print("No session keys found") } else {
            print(status)
        }

    }

    private func deletePasswords() {
        // Remove passwords
        let query: [String: Any] = [kSecClass as String: kSecClassInternetPassword]

        // Try to delete the seed if it exists.
        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound { print("No generic passwords found") } else {
            print(status)
        }
    }

    private func deleteSeed() {
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrAccount as String: "com.athena.seed"]

        // Try to delete the seed if it exists.
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecItemNotFound { print("No seed found.") } else {
            print(status)
        }
    }


}

