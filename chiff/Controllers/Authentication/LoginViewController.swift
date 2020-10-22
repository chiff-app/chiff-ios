/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication
import PromiseKit

class LoginViewController: UIViewController {

    @IBOutlet weak var authenticateButton: UIButton!

    override func viewDidLoad() {
        super.viewDidLoad()
        if Properties.hasFaceID {
            authenticateButton.setImage(UIImage(named: "face_id"), for: .normal)
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    @IBAction func touchID(_ sender: UIButton) {
        AuthenticationGuard.shared.authenticateUser(cancelChecks: false)
    }

    @IBAction func unwindToLoginViewController(sender: UIStoryboardSegue) { }

    func showDecodingError(error: DecodingError) {
        let alert = UIAlertController(title: "errors.corrupted_data".localized, message: "popups.questions.delete_corrupted".localized, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { _ in
            Logger.shared.warning("Keyn reset after corrupted data", error: error)
            self.deleteData()
        }))
        self.present(alert, animated: true, completion: nil)
    }

    func showDataDeleted() {
        authenticateButton.isEnabled = false
        let alert = UIAlertController(title: "errors.data_deleted".localized, message: "popups.questions.delete_locally".localized, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "popups.responses.restore".localized, style: .default, handler: { _ in
            firstly {
                Seed.recreateBackup()
            }.then {
                PushNotifications.register()
            }.done(on: .main) { _ in
                AuthenticationGuard.shared.authenticateUser(cancelChecks: false)
            }.catch(on: .main) { _ in
                self.showAlert(message: "errors.data_recreation_failed_message".localized, title: "errors.generic_error".localized, handler: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { _ in
            self.deleteData()
        }))
        self.present(alert, animated: true, completion: nil)
    }

    private func deleteData() {
        _ = BrowserSession.deleteAll()
        TeamSession.purgeSessionDataFromKeychain()
        UserAccount.deleteAll()
        Seed.delete()
        _ = NotificationManager.shared.deleteEndpoint()
        let storyboard: UIStoryboard = UIStoryboard.get(.initialisation)
        AppDelegate.startupService.window?.rootViewController = storyboard.instantiateViewController(withIdentifier: "InitialisationViewController")
        AuthenticationGuard.shared.hideLockWindow()
    }

}
