/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication
import JustLog

class LoginViewController: UIViewController {
    @IBOutlet weak var touchIDButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        touchIDButton.imageView!.contentMode = .scaleAspectFit
        touchIDButton.imageEdgeInsets = UIEdgeInsetsMake(13, 13, 13, 13)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    @IBAction func touchID(_ sender: UIButton) {
        Logger.shared.debug("Manual authenticate in viewDidAppear called.")
        AuthenticationGuard.shared.authenticateUser(cancelChecks: false)
    }

    @IBAction func unwindToLoginViewController(sender: UIStoryboardSegue) { }
}
