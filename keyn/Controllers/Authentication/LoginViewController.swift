//
//  LoginViewController.swift
//  keyn
//
//  Created by Bas Doorn on 09/12/2017.
//  Copyright © 2017 keyn. All rights reserved.
//

import UIKit
import LocalAuthentication
import os.log

class LoginViewController: UIViewController {

    var autoAuthentication = true
    @IBOutlet weak var touchIDButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        touchIDButton.imageView!.contentMode = .scaleAspectFit
        touchIDButton.imageEdgeInsets = UIEdgeInsetsMake(13, 13, 13, 13)
        // Do any additional setup after loading the view.
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if autoAuthentication {
            os_log("Auto authenticate in viewDidAppear called", type: .debug)
            AuthenticationGuard.sharedInstance.authenticateUser()
            //self.authenticateUser()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    // MARK: Actions
    @IBAction func touchID(_ sender: UIButton) {
        os_log("Manual authenticate in viewDidAppear called", type: .debug)
//        self.authenticateUser()
        AuthenticationGuard.sharedInstance.authenticateUser()
    }

    @IBAction func unwindToLoginViewController(sender: UIStoryboardSegue) { }
}
