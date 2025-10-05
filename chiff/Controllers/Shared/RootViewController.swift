//
//  RootViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore

class RootViewController: UITabBarController {

    override func viewDidLoad() {
        super.viewDidLoad()
        setBadge(completed: Seed.paperBackupCompleted)
        selectedIndex = Properties.deniedPushNotifications || !Properties.firstPairingCompleted ? 1 : 0
        tabBar.items?[0].title = "tabs.accounts".localized
        tabBar.items?[1].title = "tabs.devices".localized
        tabBar.items?[2].title = "tabs.settings".localized
        tabBar.unselectedItemTintColor = UIColor.primaryHalfOpacity
        tabBar.tintColor = UIColor.primary
        launchDeprecationWarning()
        NotificationCenter.default.addObserver(self, selector: #selector(showAddOTP(notification:)), name: .openAddOTP, object: nil)
    }

    func setBadge(completed: Bool) {
        if let settingsItem = tabBar.items?[2] {
            settingsItem.badgeColor = UIColor.secondary
            settingsItem.badgeValue = !completed || Properties.isJailbroken ? "!" : nil
        }
    }

    func launchDeprecationWarning() {
        if Properties.acknowledgedDeprecation {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let alert = UIAlertController(title: "popups.questions.deprecation".localized, message: "popups.questions.deprecation_message".localized, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "popups.responses.later".localized, style: .cancel))
            let moreInfoAction = UIAlertAction(title: "popups.responses.more_info".localized, style: .default, handler: { _ in
                self.performSegue(withIdentifier: "ShowTerms", sender: URL(string: "urls.deprecation".localized))
                Properties.acknowledgedDeprecation = true
            })
            alert.addAction(moreInfoAction)
            alert.preferredAction = moreInfoAction
            self.present(alert, animated: true, completion: nil)
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowTerms", let destination = segue.destination.contents as? WebViewController, let url = sender as? URL {
            destination.presentedModally = true
            destination.url = url
        } else if segue.identifier == "ShowAddOTP", let destination = segue.destination.contents as? AddOTPViewController, let url = sender as? URL {
            destination.otpUrl = url
        }
    }
    
    // MARK: - Private functions
    
    @objc private func showAddOTP(notification: Notification?) {
        DispatchQueue.main.async {
            if let userInfo = notification?.userInfo as? [String: URL], let url = userInfo["url"] {
                self.performSegue(withIdentifier: "ShowAddOTP", sender: url)
            }
        }
    }

}
