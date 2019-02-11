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
        migrateStuff()
        return true
    }

    // MARK: - Private

    private func migrateStuff() {
       //
    }
    
}
