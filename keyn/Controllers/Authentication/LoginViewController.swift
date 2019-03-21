/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication

class LoginViewController: UIViewController {
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    @IBAction func touchID(_ sender: UIButton) {
        Logger.shared.debug("Manual authenticate in viewDidAppear called.")
        AuthenticationGuard.shared.authenticateUser(cancelChecks: false)
    }

    @IBAction func unwindToLoginViewController(sender: UIStoryboardSegue) { }
}
