/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import JustLog
import UIKit

/*
 * Code that is only needed for people who have to migrate from an older version of the app to a new one.
 */
class MigrationService: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplicationLaunchOptionsKey: Any]?) -> Bool {
        detectOldAccounts()
        return true
    }

    // MARK: - Private

    // Temporary for Alpha --> Beta migration. Resets Keyn if undecodable accounts or sites are found, migrates to new Keychain otherwise.
    private func detectOldAccounts() {
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
}
