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
            self.showRootController()
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

    // MARK: - Actions

    @IBAction func tryLater(_ sender: UIButton) {
        self.showRootController()
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier, identifier == "EmbeddedPairing", let destination = segue.destination as? PairViewController {
            destination.pairControllerDelegate = self
            destination.pairContainerDelegate = self
        }
    }

}
