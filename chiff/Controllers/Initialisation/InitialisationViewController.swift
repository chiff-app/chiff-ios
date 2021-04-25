//
//  InitialisationViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import LocalAuthentication
import PromiseKit
import ChiffCore

class InitialisationViewController: UIViewController {

    @IBOutlet weak var biometricLabel: UILabel!
    @IBOutlet weak var loadingView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        setLabel()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(true)
        self.loadingView.isHidden = true
    }

    // MARK: - Actions

    @IBAction func trySetupKeyn(_ sender: Any) {
        setupKeyn()
    }

    // MARK: - Private functions

    private func setupKeyn() {
        loadingView.isHidden = false
        guard !Seed.hasKeys else {
            self.performSegue(withIdentifier: "ShowPushView", sender: self)
            return
        }
        firstly {
            LocalAuthenticationManager.shared.authenticate(reason: "initialization.initialize_keyn".localized, withMainContext: true)
        }.then { context in
            Seed.create(context: context)
        }.done(on: .main) { _ in
            self.performSegue(withIdentifier: "ShowPushView", sender: self)
            Logger.shared.analytics(.seedCreated, override: true)
        }.catch(on: .main) { error in
            self.loadingView.isHidden = true
            if let error = error as? LAError {
                if let errorMessage = LocalAuthenticationManager.shared.handleError(error: error) {
                    self.showAlert(message: "\("errors.seed_creation".localized): \(errorMessage)")
                }
            } else {
                self.showAlert(message: error.localizedDescription, title: "errors.seed_creation".localized)
            }
        }
    }

    private func setLabel() {
        let attributedText = NSMutableAttributedString(string: "initialization.log_in_with".localized, attributes: [NSAttributedString.Key.foregroundColor: UIColor.textColor])
        let key = Properties.hasFaceID ? "initialization.face_id" : "initialization.touch_id"
        attributedText.append(key.attributedLocalized(color: UIColor.secondary, font: nil, attributes: [
            NSAttributedString.Key.foregroundColor: UIColor.textColor
        ]))
        attributedText.append(NSMutableAttributedString(string: "initialization.from_today".localized, attributes: [NSAttributedString.Key.foregroundColor: UIColor.textColor]))
        biometricLabel.attributedText = attributedText
    }

}
