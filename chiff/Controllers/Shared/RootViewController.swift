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
        launchTerms()
        NotificationCenter.default.addObserver(self, selector: #selector(showAddOTP(notification:)), name: .openAddOTP, object: nil)
    }

    func setBadge(completed: Bool) {
        if let settingsItem = tabBar.items?[2] {
            settingsItem.badgeColor = UIColor.secondary
            settingsItem.badgeValue = !completed || Properties.isJailbroken ? "!" : nil
        }
    }

    func launchTerms() {
        if Properties.notifiedLatestTerms {
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            let alert = UIAlertController(title: "popups.questions.terms".localized, message: "popups.questions.updated_terms_message".localized, preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "popups.responses.dont_care".localized, style: .cancel) { _ in
                Properties.notifiedLatestTerms = true
            })
            let agreeAction = UIAlertAction(title: "popups.responses.open".localized, style: .default, handler: { _ in
                let urlPath = Bundle.main.path(forResource: "terms_of_use", ofType: "md")
                self.performSegue(withIdentifier: "ShowTerms", sender: URL(fileURLWithPath: urlPath!))
                Properties.notifiedLatestTerms = true
            })
            alert.addAction(agreeAction)
            alert.preferredAction = agreeAction
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
