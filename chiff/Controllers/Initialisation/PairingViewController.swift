//
//  PairingViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore

class PairingViewController: UIViewController {

    @IBOutlet weak var activityView: UIView!

    // MARK: - Actions

    @IBAction func tryLater(_ sender: UIButton) {
        start()
        Logger.shared.analytics(.tryLaterClicked, override: true)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier, identifier == "EmbeddedPairing", let destination = segue.destination as? PairViewController {
            destination.pairControllerDelegate = self
            destination.pairContainerDelegate = self
        }
    }

    // MARK: - Private functions

    private func start() {
        if Properties.environment == .staging {
            Properties.analyticsLogging = true
            Properties.errorLogging = true
            UIApplication.shared.showRootController()
        } else {
            self.performSegue(withIdentifier: "ShowLoggingPreferences", sender: self)
        }
    }

}

extension PairingViewController: PairControllerDelegate {

    func sessionCreated(session: Session) {
        DispatchQueue.main.async {
            self.start()
        }
    }

}

extension PairingViewController: PairContainerDelegate {

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

}
