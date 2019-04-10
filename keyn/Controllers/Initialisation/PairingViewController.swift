//
//  PairingViewController.swift
//  keyn
//
//  Created by Bas Doorn on 25/03/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class PairingViewController: UIViewController, PairControllerDelegate {

    func sessionCreated(session: Session) {
        DispatchQueue.main.async {
            // TODO: - check if notification is still needed if delegate is
            self.showRootController()
        }
    }

    func prepareForPairing(completionHandler: @escaping (_ result: Bool) -> Void) {
        initializeSeed { (error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.showError(message: "\("errors.seed_creation".localized): \(error)")
                    completionHandler(false)
                } else {
                    completionHandler(true)
                }
            }
        }
    }

    // MARK: - Private functions

    private func initializeSeed(completionHandler: @escaping (_ error: Error?) -> Void) {
        do {
            try Seed.create()
        } catch {
            completionHandler(error)
        }
        BackupManager.shared.initialize(completionHandler: completionHandler)
    }

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
        initializeSeed { (error) in
            DispatchQueue.main.async {
                if let error = error {
                    self.showError(message: "\("errors.seed_creation".localized): \(error)")
                } else {
                    self.showRootController()
                }
            }
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier, identifier == "EmbeddedPairing", let destination = segue.destination as? PairViewController {
            destination.pairControllerDelegate = self
        }
    }

}