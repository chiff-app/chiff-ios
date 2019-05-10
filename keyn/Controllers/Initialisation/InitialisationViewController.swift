/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication

class InitialisationViewController: UIViewController {

    @IBAction func setupKeyn(_ sender: UIButton) {
        if Seed.hasKeys && BackupManager.shared.hasKeys {
            registerForPushNotifications()
        } else {
            initializeSeed { (error) in
                DispatchQueue.main.async {
                    if let error = error as? LAError {
                        if let errorMessage = LocalAuthenticationManager.shared.handleError(error: error) {
                            self.showError(message:"\("errors.seed_creation".localized): \(errorMessage)")
                        }
                    } else if let error = error {
                        self.showError(message:"\("errors.seed_creation".localized): \(error)")
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
                    NotificationManager.shared.subscribe(topic: Properties.notificationTopic, completion: nil)
                    self.performSegue(withIdentifier: "ShowPairingExplanation", sender: self)
                } else {
                    // TODO: Present warning vc, then continue to showRootVC
                    self.showRootController()
                }
            }
        }
    }

    private func initializeSeed(completionHandler: @escaping (_ error: Error?) -> Void) {
        LocalAuthenticationManager.shared.authenticate(reason: "initialization.initialize_keyn".localized, withMainContext: true) { (context, error) in
            if let error = error {
                completionHandler(error)
                return
            }
            Seed.create(context: context, completionHandler: completionHandler)
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
