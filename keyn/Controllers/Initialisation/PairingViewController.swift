//
//  PairingViewController.swift
//  keyn
//
//  Created by Bas Doorn on 25/03/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class PairingViewController: UIViewController, PairControllerDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
    }

    func sessionCreated(session: Session) {
        DispatchQueue.main.async {
            // TODO: - check if notification is still needed if delegate is
            self.showRootController()
        }
    }

    func prepareForPairing(completionHandler: @escaping (_ result: Bool) -> Void) {
        do {
            try initializeSeed(completionHandler: completionHandler)
        } catch {
            print(error)
            completionHandler(false)
        }
    }

    // MARK: - Private functions

    private func initializeSeed(completionHandler: @escaping (_: Bool) -> Void) throws {
        try Seed.create()
        try BackupManager.shared.initialize(completionHandler: completionHandler)
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
        do {
            try initializeSeed { (result) in
                DispatchQueue.main.async {
                    guard result else {
                        print("Error creating backup entry") // TODO: show error
                        return
                    }
                    self.showRootController()
                }
            }
        } catch {
            print(error)
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let identifier = segue.identifier, identifier == "EmbeddedPairing", let destination = segue.destination as? PairViewController {
            destination.pairControllerDelegate = self
        }
    }

}
