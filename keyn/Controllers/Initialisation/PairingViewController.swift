//
//  PairingViewController.swift
//  keyn
//
//  Created by Bas Doorn on 25/03/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class PairingViewController: UIViewController, PairControllerDelegate, PairContainerDelegate {

    @IBOutlet weak var activityView: UIView!

    func sessionCreated(session: Session) {
        DispatchQueue.main.async {
            // TODO: - check if notification is still needed if delegate is
            self.start()
        }
    }

    func startLoading() {
        DispatchQueue.main.async {
            self.activityView.isHidden = false
        }
    }

    func finishLoading() {
        func startLoading() {
            DispatchQueue.main.async {
                self.activityView.isHidden = true
            }
        }
    }

    // MARK: - Actions

    @IBAction func tryLater(_ sender: UIButton) {
        start()
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier, identifier == "EmbeddedPairing", let destination = segue.destination as? PairViewController {
            destination.pairControllerDelegate = self
            destination.pairContainerDelegate = self
        }
    }

    private func start() {
        if Properties.environment == .beta {
            Properties.analyticsLogging = true
            Properties.errorLogging = true
            UIApplication.shared.showRootController()
        } else {
            self.performSegue(withIdentifier: "ShowLoggingPreferences", sender: self)
        }
    }

}
