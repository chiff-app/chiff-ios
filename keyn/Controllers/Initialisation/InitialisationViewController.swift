/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class InitialisationViewController: UIViewController {

    @IBAction func setupKeyn(_ sender: UIButton) {
        if Seed.hasKeys && BackupManager.shared.hasKeys {
            registerForPushNotifications()
        } else {
            initializeSeed { (error) in
                DispatchQueue.main.async {
                    if let error = error {
                        self.showError(message: "Error creating seed: \(error)")
                    } else {
                        self.registerForPushNotifications()
                    }
                }
            }
        }

    }

    // MARK: - Private functions

    private func registerForPushNotifications() {
        let appDelegate = UIApplication.shared.delegate! as! AppDelegate
        let startupService = appDelegate.services.first(where: { $0.key == .appStartup })!.value as! AppStartupService
        startupService.registerForPushNotifications() { result in
            DispatchQueue.main.async {
                if result {
                    self.performSegue(withIdentifier: "ShowPairingExplanation", sender: self)
                } else {
                    // TODO: Present warning vc, then continue to showRootVC
                    self.showRootController()
                }
            }
        }
    }

    private func initializeSeed(completionHandler: @escaping (_ error: Error?) -> Void) {
        do {
            try Seed.create()
            BackupManager.shared.initialize(completionHandler: completionHandler)
        } catch {
            completionHandler(error)
        }
    }

    private func showRootController() {
        guard let window = UIApplication.shared.keyWindow else {
            return
        }
        guard let vc = UIStoryboard.main.instantiateViewController(withIdentifier: "RootController") as? RootViewController else {
            Logger.shared.error("Unexpected root view controller type")
            fatalError("Unexpected root view controller type")
        }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            DispatchQueue.main.async {
                window.rootViewController = vc
            }
        })
    }

}
