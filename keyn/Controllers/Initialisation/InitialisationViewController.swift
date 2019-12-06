/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication

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
        guard !Seed.hasKeys && !BackupManager.shared.hasKeys else {
            self.performSegue(withIdentifier: "ShowPushView", sender: self)
            return
        }
        initializeSeed { (result) in
            DispatchQueue.main.async {
                switch result {
                case .success(_):
                    self.performSegue(withIdentifier: "ShowPushView", sender: self)
                    Logger.shared.analytics(.seedCreated, override: true)
                case .failure(let error):
                    self.loadingView.isHidden = true
                    if let error = error as? LAError {
                        if let errorMessage = LocalAuthenticationManager.shared.handleError(error: error) {
                            self.showError(message:"\("errors.seed_creation".localized): \(errorMessage)")
                        }
                    } else {
                        self.showError(message: error.localizedDescription, title: "errors.seed_creation".localized)
                    }
                }
            }
        }
    }

    private func initializeSeed(completionHandler: @escaping (Result<Void, Error>) -> Void) {
        LocalAuthenticationManager.shared.authenticate(reason: "initialization.initialize_keyn".localized, withMainContext: true) { (result) in
            switch result {
            case .success(let context): Seed.create(context: context, completionHandler: completionHandler)
            case .failure(let error): completionHandler(.failure(error))
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
