/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication
import OneTimePassword
import PromiseKit

class RequestViewController: UIViewController {

    @IBOutlet weak var requestLabel: UILabel!
    @IBOutlet weak var successView: BackupCircle!
    @IBOutlet weak var successTextLabel: UILabel!
    @IBOutlet weak var successTextDetailLabel: UILabel!
    @IBOutlet weak var checkmarkHeightContstraint: NSLayoutConstraint!
    @IBOutlet weak var authenticateButton: UIButton!
    @IBOutlet weak var progressLabel: UILabel!
    @IBOutlet weak var successImageView: UIImageView!
    @IBOutlet weak var activityIndicator: UIActivityIndicatorView!

    var authorizer: Authorizer!

    private var authorized = false
    private var accounts = [Account]()

    private var account: Account?
    private var otpCodeTimer: Timer?
    private var token: Token?

    override func viewDidLoad() {
        super.viewDidLoad()
        if Properties.hasFaceID {
            authenticateButton.setImage(UIImage(named: "face_id"), for: .normal)
        }
        requestLabel.text = authorizer.requestText
        acceptRequest()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    // MARK: - Private functions

    private func acceptRequest() {
        firstly {
            authorizer.authorize { message in
                DispatchQueue.main.async { [weak self] in
                    self?.activityIndicator.startAnimating()
                    if let message = message {
                        self?.progressLabel.isHidden = false
                        self?.progressLabel.text = message
                    }
                }
            }
        }.ensure {
            AuthorizationGuard.shared.authorizationInProgress = false
        }.done(on: .main) { account in
            self.activityIndicator.stopAnimating()
            self.progressLabel.isHidden = true
            if var account = account {
                account.increaseUse()
                NotificationCenter.default.post(name: .accountUpdated, object: self, userInfo: ["account": account])
            }
            self.authenticateButton.isHidden = true
            if let account = account as? UserAccount, account.hasOtp, let token = try? account.oneTimePasswordToken() {
                self.token = token
                self.account = account
                self.showOtp()
            } else {
                self.success()
            }
        }.catch(on: .main) { error in
            self.activityIndicator.stopAnimating()
            self.handleError(error: error)
        }
    }

    private func handleError(error: Error) {
        if let error = error as? AuthorizationError {
            switch error {
            case .cannotChangeAccount:
                self.showAlert(message: "errors.shared_account_change".localized)
            case .noTeamSessionFound:
                self.showAlert(message: "errors.no_team".localized)
            case .notAdmin:
                self.showAlert(message: "errors.no_admin".localized)
            case .inProgress, .missingData, .unknownType:
                return
            }
            AuthenticationGuard.shared.hideLockWindow()
        } else if let error = error as? APIError {
            Logger.shared.error("APIError authorizing request", error: error)
            guard self.authorizer.type == .createOrganisation else {
                self.showAlert(message: "\("errors.api_error".localized): \(error)")
                return
            }
            switch error {
            case APIError.statusCode(409):
                self.showAlert(message: "errors.organisation_exists".localized)
            case APIError.statusCode(402):
                self.showAlert(message: "errors.payment_required".localized)
            default:
                self.showAlert(message: "\("errors.api_error".localized): \(error)")
            }
        } else if let error = error as? PasswordGenerationError {
            self.showAlert(message: "\("errors.password_generation".localized) \(error)")
        } else if case AccountError.importError(failed: let failed, total: let total) = error {
            self.showAlert(message: String(format: "errors.failed_accounts_message".localized, failed, total)) { _ in
                self.dismiss()
                AuthenticationGuard.shared.hideLockWindow()
            }
        } else if let errorMessage = LocalAuthenticationManager.shared.handleError(error: error) {
            self.showAlert(message: errorMessage)
            Logger.shared.error("Error authorizing request", error: error)
        } else {
            Logger.shared.error("Error authorizing request", error: error)
        }
    }

    private func showOtp() {
        successTextLabel.font = successTextLabel.font.withSize(32.0)
        successTextLabel.text = token!.currentPasswordSpaced
        checkmarkHeightContstraint.constant = 0
        switch token!.generator.factor {
        case .counter:
            authenticateButton.setImage(UIImage(named: "refresh"), for: .normal)
            authenticateButton.imageView?.contentMode = .scaleAspectFit
        case .timer(let period):
            let start = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: period)
            successView.removeCircleAnimation()
            successView.draw(color: UIColor.white.cgColor, backgroundColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.1).cgColor)
            otpCodeTimer = Timer.scheduledTimer(withTimeInterval: period - start, repeats: false, block: { (_) in
                self.successTextLabel.text = self.token!.currentPasswordSpaced
                self.otpCodeTimer = Timer.scheduledTimer(timeInterval: period, target: self, selector: #selector(self.updateTOTP), userInfo: nil, repeats: true)
            })
            successView.startCircleAnimation(duration: period, start: start)
        }
        successTextDetailLabel.text = "requests.enter_otp".localized
        self.authorized = true
        self.showSuccessView()
    }

    @objc func updateTOTP() {
        successTextLabel.text = token?.currentPasswordSpaced ?? ""
    }

    private func success() {
        successTextLabel.text = authorizer.successText
        successTextDetailLabel.text = authorizer.succesDetailText
        self.authorized = true
        self.showSuccessView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.50) {
            AuthenticationGuard.shared.hideLockWindow(delay: 0.15)
            self.dismiss()
        }
    }

    private func showSuccessView() {
        self.successView.alpha = 0.0
        self.successView.isHidden = false
        UIView.animate(withDuration: 0.3, delay: 0.0, options: [.curveLinear], animations: { self.successView.alpha = 1.0 })
    }

    // MARK: - Actions

    @IBAction func authenticate(_ sender: UIButton) {
        if let factor = token?.generator.factor, case .counter = factor, let newToken = token?.updatedToken() {
            self.token = newToken
            var userAccount = account as? UserAccount
            try? userAccount?.setOtp(token: newToken)
            successTextLabel.text = newToken.currentPasswordSpaced
        } else {
            acceptRequest()
        }
    }

    @IBAction func close(_ sender: UIButton) {
        guard authorized else {
            return firstly {
                authorizer.rejectRequest()
            }.done(on: .main) {
                self.dismiss()
            }.catchLog("Error rejecting request")
        }
        dismiss()
        AuthenticationGuard.shared.hideLockWindow(delay: 0.15)
    }

    // MARK: - Navigation

    func dismiss() {
        presentingViewController?.dismiss(animated: true, completion: nil) ?? dismiss(animated: true, completion: nil)
    }

}
