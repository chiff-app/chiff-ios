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
        case .login, .addToExisting:
            requestLabel.text = "requests.confirm_login".localized.capitalizedFirstLetter
            Logger.shared.analytics(.loginRequestOpened)
        case .add, .addAndLogin:
            requestLabel.text = "requests.add_account".localized.capitalizedFirstLetter
            Logger.shared.analytics(.addSiteRequestOpened)
        case .addBulk:
            requestLabel.text = "requests.add_accounts".localized.capitalizedFirstLetter
            Logger.shared.analytics(.addBulkSitesRequestOpened)
        case .change:
            requestLabel.text = "requests.change_password".localized.capitalizedFirstLetter
            Logger.shared.analytics(.changePasswordRequestOpened)
        case .fill:
            requestLabel.text = "requests.fill_password".localized.capitalizedFirstLetter
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
        authorizationGuard.acceptRequest { result in
            DispatchQueue.main.async {
                switch result {
                case .success(let account):
                    if let account = account, account.hasOtp {
                        AuthenticationGuard.shared.hideLockWindow()
                        self.account = account
                        self.showOtp()
                    } else {
                        AuthenticationGuard.shared.hideLockWindow()
                        self.success()
                    }
                case .failure(let error):
                    if let error = error as? AuthorizationError {
                        switch error {
                        case .accountOverflow: self.shouldUpgrade(title: "requests.account_disabled".localized.capitalizedFirstLetter, description: "requests.upgrade_keyn_for_request".localized.capitalizedFirstLetter)
                        case .cannotAddAccount: self.shouldUpgrade(title: "requests.cannot_add".localized.capitalizedFirstLetter, description: "requests.upgrade_keyn_for_add".localized.capitalizedFirstLetter)
                        }
                        AuthenticationGuard.shared.hideLockWindow()
                    } else if let errorMessage = LocalAuthenticationManager.shared.handleError(error: error) {
                        self.showError(message: errorMessage)
                        Logger.shared.error("Error authorizing request", error: error)
                    }
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
        self.authorized = true
        self.showSuccessView()
    }

    @objc func updateTOTP() {
        successTextLabel.text = token?.currentPasswordSpaced ?? ""
    }

    private func success() {
        var autoClose = true
        switch authorizationGuard.type {
            case .login, .addToExisting:
                successTextLabel.text = "requests.login_succesful".localized.capitalizedFirstLetter
                successTextDetailLabel.text = "requests.return_to_computer".localized.capitalizedFirstLetter
            case .add, .addAndLogin:
                successTextLabel.text = "requests.account_added".localized.capitalizedFirstLetter
                successTextDetailLabel.text = "requests.login_keyn_next_time".localized.capitalizedFirstLetter
                autoClose = setAccountsLeft()
            case .addBulk:
                successTextLabel.text = "\(authorizationGuard.accounts.count) \("requests.accounts_added".localized)"
                successTextDetailLabel.text = "requests.login_keyn_next_time".localized.capitalizedFirstLetter
                autoClose = setAccountsLeft()
            case .change:
                successTextLabel.text = "requests.new_password_generated".localized.capitalizedFirstLetter
                successTextDetailLabel.text = "\("requests.return_to_computer".localized.capitalizedFirstLetter) \("requests.to_complete_process".localized)"
            case .fill:
                successTextLabel.text = "requests.fill_password_successful".localized.capitalizedFirstLetter
                successTextDetailLabel.text = "requests.return_to_computer".localized.capitalizedFirstLetter
            default:
                requestLabel.text = "requests.unknown_request".localized.capitalizedFirstLetter
        }
        self.authorized = true
        self.showSuccessView()
        if autoClose {
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                self.dismiss()
            }
        }
    }

    // "requests.account_disabled".localized.capitalizedFirstLetter
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
            dismiss()
        }

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
