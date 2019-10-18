/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication

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
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { action in
            do {
                Session.deleteAll()
                Account.deleteAll()
                try Seed.delete()
                NotificationManager.shared.deleteEndpoint()
                BackupManager.shared.deleteAllKeys()
                Logger.shared.warning("Keyn reset after corrupted data", error: error)
                let storyboard: UIStoryboard = UIStoryboard.get(.initialisation)
                UIApplication.shared.keyWindow?.rootViewController = storyboard.instantiateViewController(withIdentifier: "InitialisationViewController")
                AuthenticationGuard.shared.hideLockWindow()
            } catch {
                fatalError()
            }
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
}
