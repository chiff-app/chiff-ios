/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication
import OneTimePassword

class RequestViewController: UIViewController {

    @IBOutlet weak var requestLabel: UILabel!
    @IBOutlet weak var successView: BackupCircle!
    @IBOutlet weak var successTextLabel: UILabel!
    @IBOutlet weak var successTextDetailLabel: UILabel!
    @IBOutlet weak var checkmarkHeightContstraint: NSLayoutConstraint!
    @IBOutlet weak var authenticateButton: UIButton!

    var authorizationGuard: AuthorizationGuard!

    private var authorized = false
    private var accounts = [Account]()

    private var account: Account?
    private var otpCodeTimer: Timer?
    private var token: Token?

    override func viewDidLoad() {
        super.viewDidLoad()
        switch authorizationGuard.type {
        case .login:
            requestLabel.text = "requests.confirm_login".localized.capitalizedFirstLetter
        case .add, .addAndLogin, .addToExisting:
            requestLabel.text = "requests.add_account".localized.capitalizedFirstLetter
        case .addBulk:
            requestLabel.text = "requests.add_accounts".localized.capitalizedFirstLetter
        case .change:
            requestLabel.text = "requests.change_password".localized.capitalizedFirstLetter
        case .fill:
            requestLabel.text = "requests.fill_password".localized.capitalizedFirstLetter
        default:
            requestLabel.text = "requests.unknown_request".localized.capitalizedFirstLetter
        }
        acceptRequest()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    // MARK: - Private functions

    private func acceptRequest() {
        authorizationGuard.acceptRequest { account, error in
            DispatchQueue.main.async {
                if let error = error {
                    if let errorMessage = LocalAuthenticationManager.shared.handleError(error: error) {
                        self.showError(message: errorMessage)
                        Logger.shared.error("Error authorizing request", error: error)
                    }
                } else if let account = account, account.hasOtp() {
                    self.account = account
                    self.showOtp()
                } else {
                    self.success()
                }
            }
        }
    }

    private func showOtp() {
        guard let token = try? account?.oneTimePasswordToken() else {
            self.success()
            return
        }
        self.token = token
        successTextLabel.font = successTextLabel.font.withSize(32.0)
        successTextLabel.text = token.currentPasswordSpaced
        checkmarkHeightContstraint.constant = 0
        switch token.generator.factor {
        case .counter(_):
            authenticateButton.setImage(UIImage(named: "refresh"), for: .normal)
            authenticateButton.imageView?.contentMode = .scaleAspectFit
        case .timer(let period):
            let start = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: period)
            successView.removeCircleAnimation()
            successView.draw(color: UIColor.white.cgColor, backgroundColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.1).cgColor)
            otpCodeTimer = Timer.scheduledTimer(withTimeInterval: period - start, repeats: false, block: { (timer) in
                self.successTextLabel.text = token.currentPasswordSpaced
                self.otpCodeTimer = Timer.scheduledTimer(timeInterval: period, target: self, selector: #selector(self.updateTOTP), userInfo: nil, repeats: true)
            })
            successView.startCircleAnimation(duration: period, start: start)
        }
        successTextDetailLabel.text = "Enter your one-time password"
        self.showSuccessView()
    }

    @objc func updateTOTP() {
        successTextLabel.text = token?.currentPasswordSpaced ?? ""
    }

    private func success() {
        switch authorizationGuard.type {
            case .login:
                successTextLabel.text = "requests.login_succesful".localized.capitalizedFirstLetter
                successTextDetailLabel.text = "requests.return_to_computer".localized.capitalizedFirstLetter
            case .add, .addToExisting, .addAndLogin:
                successTextLabel.text = "requests.account_added".localized.capitalizedFirstLetter
                successTextDetailLabel.text = "requests.login_keyn_next_time".localized.capitalizedFirstLetter
            case .addBulk:
                successTextLabel.text = "\(authorizationGuard.accounts.count) \("requests.accounts_added".localized)"
                successTextDetailLabel.text = "requests.login_keyn_next_time".localized.capitalizedFirstLetter
            case .change:
                successTextLabel.text = "requests.new_password_generated".localized.capitalizedFirstLetter
                successTextDetailLabel.text = "\("requests.return_to_computer".localized.capitalizedFirstLetter) \("requests.to_complete_process".localized)"
            case .fill:
                successTextLabel.text = "requests.fill_password_successful".localized.capitalizedFirstLetter
                successTextDetailLabel.text = "requests.return_to_computer".localized.capitalizedFirstLetter
            default:
                requestLabel.text = "requests.unknown_request".localized.capitalizedFirstLetter
        }
        self.showSuccessView()
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.dismiss(animated: true, completion: nil)
            AuthenticationGuard.shared.hideLockWindow()
        }
    }

    private func showSuccessView() {
        self.successView.alpha = 0.0
        self.successView.isHidden = false
        self.authorized = true
        UIView.animate(withDuration: 0.3, delay: 0.0, options: [.curveLinear], animations: { self.successView.alpha = 1.0 })
    }

    // MARK: - Actions

    @IBAction func authenticate(_ sender: UIButton) {
        if let factor = token?.generator.factor, case .counter(_) = factor, let newToken = token?.updatedToken() {
            self.token = newToken
            try? account?.setOtp(token: newToken)
            successTextLabel.text = newToken.currentPasswordSpaced
        } else {
            acceptRequest()
        }
    }

    @IBAction func close(_ sender: UIButton) {
        if !authorized {
            authorizationGuard.rejectRequest() {
                DispatchQueue.main.async {
                    self.dismiss(animated: true, completion: nil)
                }
            }
        } else {
            self.dismiss(animated: true, completion: nil)
        }

    }

}
