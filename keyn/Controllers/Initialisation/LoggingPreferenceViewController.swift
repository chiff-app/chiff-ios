//
//  LoggingPreferenceViewController.swift
//  keyn
//
//  Created by Bas Doorn on 30/05/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class LoggingPreferenceViewController: UIViewController {

    override func viewDidLoad() {
        self.navigationItem.setHidesBackButton(true, animated: true)
    }

    // MARK: - Actions

    @IBAction func shareErrorData(_ sender: UISwitch) {
        Properties.errorLogging = sender.isOn
    }

    @IBAction func shareAnalyticalData(_ sender: UISwitch) {
        Properties.analyticsLogging = sender.isOn
    }

    @IBAction func finish(_ sender: UIButton) {
        showRootController()
    }

    // MARK: - Private functions

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
