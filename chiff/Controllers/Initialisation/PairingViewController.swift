//
//  PairingViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

class PairingViewController: UIViewController, PairControllerDelegate, PairContainerDelegate {

    @IBOutlet weak var activityView: UIView!

    func sessionCreated(session: Session) {
        DispatchQueue.main.async {
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
        Logger.shared.analytics(.tryLaterClicked, override: true)
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
