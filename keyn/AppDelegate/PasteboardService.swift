/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

/*
 * Clears copied password from clipboard after a specified time.
 */
class PasteboardService: NSObject, UIApplicationDelegate {
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        let nc = NotificationCenter.default
        nc.addObserver(forName: UIPasteboard.changedNotification, object: nil, queue: nil, using: handlePasteboardChangeNotification)

        return true
    }

    private func handlePasteboardChangeNotification(notification: Notification) {
        let pasteboard = UIPasteboard.general
        guard let text = pasteboard.string, text != "" else {
            return
        }

        let pasteboardVersion = pasteboard.changeCount
        let clearPasteboardTimeout = 60.0 // TODO: hardcoded for now. This should be editable in settings I guess?

        var backgroundTask: UIBackgroundTaskIdentifier = UIBackgroundTaskIdentifier.invalid
        backgroundTask = UIApplication.shared.beginBackgroundTask(expirationHandler: {
            UIApplication.shared.endBackgroundTask(convertToUIBackgroundTaskIdentifier(backgroundTask.rawValue))
            backgroundTask = UIBackgroundTaskIdentifier.invalid
        })

        DispatchQueue.global(qos: .default).asyncAfter(deadline: .now() + clearPasteboardTimeout) {
            if pasteboardVersion == pasteboard.changeCount {
                pasteboard.string = ""
            }

            if backgroundTask != UIBackgroundTaskIdentifier.invalid {
                UIApplication.shared.endBackgroundTask(convertToUIBackgroundTaskIdentifier(backgroundTask.rawValue))
            }
        }
    }
}

// Helper function inserted by Swift 4.2 migrator.
fileprivate func convertToUIBackgroundTaskIdentifier(_ input: Int) -> UIBackgroundTaskIdentifier {
	return UIBackgroundTaskIdentifier(rawValue: input)
}
