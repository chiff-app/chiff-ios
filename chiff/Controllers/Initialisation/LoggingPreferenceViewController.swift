//
//  LoggingPreferenceViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

class LoggingPreferenceViewController: UIViewController {

    @IBOutlet weak var shareErrorDataSwitch: UISwitch!
    @IBOutlet weak var shareAnalyticsDataSwitch: UISwitch!

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
        Properties.analyticsLogging = shareAnalyticsDataSwitch.isOn
        Properties.errorLogging = shareErrorDataSwitch.isOn
        UIApplication.shared.showRootController()
    }

}
