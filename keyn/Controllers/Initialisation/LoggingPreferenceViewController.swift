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
        UIApplication.shared.showRootController()
    }

}
