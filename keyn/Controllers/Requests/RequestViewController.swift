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
    @IBOutlet weak var successImageView: UIImageView!
    @IBOutlet weak var upgradeStackView: UIView!
    @IBOutlet weak var accountsLeftLabel: UILabel!


    var authorizationGuard: AuthorizationGuard!

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
        switch authorizationGuard.type {
        case .login, .addToExisting, .adminLogin, .webauthnLogin, .bulkLogin:
            requestLabel.text = "requests.confirm_login".localized.capitalizedFirstLetter
            Logger.shared.analytics(.loginRequestOpened)
        case .add, .addAndLogin, .webauthnCreate:
            requestLabel.text = "requests.add_account".localized.capitalizedFirstLetter
            Logger.shared.analytics(.addSiteRequestOpened)
        case .addBulk:
            requestLabel.text = "requests.add_accounts".localized.capitalizedFirstLetter
            Logger.shared.analytics(.addBulkSitesRequestOpened)
        case .change:
            requestLabel.text = "requests.change_password".localized.capitalizedFirstLetter
            Logger.shared.analytics(.changePasswordRequestOpened)
        case .fill, .getDetails:
            requestLabel.text = "requests.get_password".localized.capitalizedFirstLetter
            Logger.shared.analytics(.fillPassworddRequestOpened)
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
        firstly {
            authorizationGuard.acceptRequest()
        }.done(on: .main) { account in
            if var account = account {
                account.increaseUse()
                NotificationCenter.default.post(name: .accountUpdated, object: nil, userInfo: ["account": account])
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
            if let error = error as? AuthorizationError {
                switch error {
                case .accountOverflow: self.shouldUpgrade(title: "requests.account_disabled".localized.capitalizedFirstLetter, description: "requests.upgrade_keyn_for_request".localized.capitalizedFirstLetter)
                case .cannotAddAccount: self.shouldUpgrade(title: "requests.cannot_add".localized.capitalizedFirstLetter, description: "requests.upgrade_keyn_for_add".localized.capitalizedFirstLetter)
                case .cannotChangeAccount:
                    self.showAlert(message: "errors.shared_account_change".localized)
                case .noTeamSessionFound:
                    self.showAlert(message: "errors.no_team".localized)
                case .notAdmin:
                    self.showAlert(message: "errors.no_admin".localized)
                case .inProgress:
                    return
                }
                AuthenticationGuard.shared.hideLockWindow()
            } else if let error = error as? APIError {
                Logger.shared.error("APIError authorizing request", error: error)
            } else if let error = error as? PasswordGenerationError {
                self.showAlert(message: "\("errors.password_generation".localized) \(error)")
            } else if let errorMessage = LocalAuthenticationManager.shared.handleError(error: error) {
                self.showAlert(message: errorMessage)
                Logger.shared.error("Error authorizing request", error: error)
            } else {
                Logger.shared.error("Error authorizing request", error: error)
            }
        }
    }

    private func showOtp() {
        successTextLabel.font = successTextLabel.font.withSize(32.0)
        successTextLabel.text = token!.currentPasswordSpaced
        checkmarkHeightContstraint.constant = 0
        switch token!.generator.factor {
        case .counter(_):
            authenticateButton.setImage(UIImage(named: "refresh"), for: .normal)
            authenticateButton.imageView?.contentMode = .scaleAspectFit
        case .timer(let period):
            let start = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: period)
            successView.removeCircleAnimation()
            successView.draw(color: UIColor.white.cgColor, backgroundColor: UIColor(red: 1, green: 1, blue: 1, alpha: 0.1).cgColor)
            otpCodeTimer = Timer.scheduledTimer(withTimeInterval: period - start, repeats: false, block: { (timer) in
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
        var autoClose = true
        switch authorizationGuard.type {
        case .login, .addToExisting, .adminLogin, .webauthnLogin, .bulkLogin:
            successTextLabel.text = "requests.login_succesful".localized.capitalizedFirstLetter
            successTextDetailLabel.text = "requests.return_to_computer".localized.capitalizedFirstLetter
        case .add, .addAndLogin, .webauthnCreate:
            successTextLabel.text = "requests.account_added".localized.capitalizedFirstLetter
            successTextDetailLabel.text = "requests.login_keyn_next_time".localized.capitalizedFirstLetter
            autoClose = setAccountsLeft()
        case .addBulk:
            successTextLabel.text = "\(authorizationGuard.count!) \("requests.accounts_added".localized)"
            successTextDetailLabel.text = "requests.login_keyn_next_time".localized.capitalizedFirstLetter
            autoClose = setAccountsLeft()
        case .change:
            successTextLabel.text = "requests.new_password_generated".localized.capitalizedFirstLetter
            successTextDetailLabel.text = "\("requests.return_to_computer".localized.capitalizedFirstLetter) \("requests.to_complete_process".localized)"
        case .fill, .getDetails:
            successTextLabel.text = "requests.get_password_successful".localized.capitalizedFirstLetter
            successTextDetailLabel.text = "requests.return_to_computer".localized.capitalizedFirstLetter
        default:
            requestLabel.text = "requests.unknown_request".localized.capitalizedFirstLetter
        }
        self.authorized = true
        self.showSuccessView()
        if autoClose {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.50) {
                AuthenticationGuard.shared.hideLockWindow(delay: 0.15)
                self.dismiss()
            }
        }
    }

    private func shouldUpgrade(title: String, description: String) {
        authenticateButton.isHidden = true
        upgradeStackView.isHidden = false
        successImageView.image = UIImage(named: "unhappy")
        requestLabel.text = title
        successTextLabel.text = ""
        successTextDetailLabel.text = description
        self.showSuccessView()
    }

    private func showSuccessView() {
        self.successView.alpha = 0.0
        self.successView.isHidden = false
        UIView.animate(withDuration: 0.3, delay: 0.0, options: [.curveLinear], animations: { self.successView.alpha = 1.0 })
    }

    private func setAccountsLeft() -> Bool {
        guard !Properties.hasValidSubscription else {
            return true
        }
        upgradeStackView.isHidden = false
        authenticateButton.isHidden = true
        accountsLeftLabel.isHidden = false
        let accountsLeft = Properties.accountCap - Properties.accountCount
        // TODO: Use stringsdict for this
        if accountsLeft == 0 {
            accountsLeftLabel.attributedText = NSAttributedString(string: "requests.no_accounts_left".localized, attributes: [NSAttributedString.Key.font: UIFont.primaryMediumNormal!])
        } else {
            let attributedText = NSMutableAttributedString(string: "requests.accounts_left_1".localized, attributes: [NSAttributedString.Key.font: UIFont.primaryMediumNormal!])
            attributedText.append(NSMutableAttributedString(string: " \(accountsLeft) \(accountsLeft == 1 ? "requests.accounts_left_2_single".localized : "requests.accounts_left_2_plural".localized) ", attributes: [NSAttributedString.Key.font: UIFont.primaryBold!]))
            attributedText.append(NSMutableAttributedString(string: "requests.accounts_left_3".localized, attributes: [NSAttributedString.Key.font: UIFont.primaryMediumNormal!]))
            accountsLeftLabel.attributedText = attributedText
        }
        return false
    }

    // MARK: - Actions

    @IBAction func authenticate(_ sender: UIButton) {
        if let factor = token?.generator.factor, case .counter(_) = factor, let newToken = token?.updatedToken() {
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
                authorizationGuard.rejectRequest()
            }.done(on: .main) {
                self.dismiss()
            }.catchLog("Error rejecting request")
        }
        AuthenticationGuard.shared.hideLockWindow(delay: 0.15)
        dismiss()
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination.contents as? SubscriptionViewController {
            destination.presentedModally = true
        }
    }

    func dismiss() {
        presentingViewController?.dismiss(animated: true, completion: nil) ?? dismiss(animated: true, completion: nil)
    }

}
