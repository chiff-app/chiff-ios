//
//  LoginViewController.swift
//  keyn
//
//  Created by Bas Doorn on 09/12/2017.
//  Copyright © 2017 keyn. All rights reserved.
//

import UIKit
import LocalAuthentication
import JustLog

class LoginViewController: UIViewController {

    @IBOutlet weak var touchIDButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        touchIDButton.imageView!.contentMode = .scaleAspectFit
        touchIDButton.imageEdgeInsets = UIEdgeInsetsMake(13, 13, 13, 13)
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    // MARK: Actions
    @IBAction func touchID(_ sender: UIButton) {
        Logger.shared.debug("Manual authenticate in viewDidAppear called.")
        AuthenticationGuard.sharedInstance.authenticateUser(cancelChecks: false)
    }

    @IBAction func unwindToLoginViewController(sender: UIStoryboardSegue) { }
}
