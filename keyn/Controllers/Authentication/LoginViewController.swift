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

    @IBOutlet weak var touchIDButton: UIButton!
    @IBOutlet weak var powerModeSwitch: UISwitch!
    var originalBrightness: CGFloat?
    
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
    
    private func togglePowerMode(on: Bool) {
        UIApplication.shared.isIdleTimerDisabled = on
        if originalBrightness == nil {
            originalBrightness = UIScreen.main.brightness
        }
        UIScreen.main.brightness = on ? min(originalBrightness ?? 1.0, 0.1) : originalBrightness ?? 0.5
    }

    // MARK: Actions
    @IBAction func touchID(_ sender: UIButton) {
        os_log("Manual authenticate in viewDidAppear called", type: .debug)
        powerModeSwitch.setOn(false, animated: true)
        togglePowerMode(on: false)
        AuthenticationGuard.sharedInstance.authenticateUser(cancelChecks: false)
    }

    @IBAction func unwindToLoginViewController(sender: UIStoryboardSegue) { }
    
    @IBAction func powerModeAction(_ sender: UISwitch) {
        togglePowerMode(on: sender.isOn)
    }
}
