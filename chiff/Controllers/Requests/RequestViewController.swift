//
//  RequestViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import LocalAuthentication
import OneTimePassword
import PromiseKit
import ChiffCore
import StoreKit

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
    @IBOutlet weak var pickerView: UIPickerView!

    var authorizer: Authorizer!

    private var authorized = false
    private var accounts = [Account]()
    private var account: Account?
    private var otpCodeTimer: Timer?
    private var token: Token?
    private var showAuthorizationAlert = false
    lazy var teamSessions: [TeamSession] = {
        return (try? TeamSession.all().filter({ $0.isAdmin })) ?? []
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        if Properties.hasFaceID {
            showAuthorizationAlert = !Properties.autoShowAuthorization
            authenticateButton.setImage(UIImage(named: "face_id"), for: .normal)
        }
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(applicationDidEnterBackground(notification:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        pickerView.dataSource = self
        pickerView.delegate = self
        requestLabel.text = authorizer.requestText
        if self.authorizer is TeamAdminLoginAuthorizer && !teamSessions.isEmpty {
            (self.authorizer as? TeamAdminLoginAuthorizer)?.teamSession = teamSessions.first
            if teamSessions.count > 1 {
                self.pickerView.isHidden = false
                showAuthorizationAlert = false
                requestLabel.text = "requests.pick_team".localized
                progressLabel.isHidden = false
                progressLabel.text = "requests.click_authorize_button".localized
                return
            }
        }
        if !showAuthorizationAlert {
            acceptRequest()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard showAuthorizationAlert else { return }
        showAuthorizationAlert = false
        let alert = UIAlertController(title: authorizer.requestText, message: authorizer.authenticationReason, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.authorize".localized, style: .default) { _ in
            self.acceptRequest()
        })
        alert.addAction(UIAlertAction(title: "popups.responses.deny".localized, style: .destructive, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    // MARK: - Actions

    @IBAction func authenticate(_ sender: UIButton) {
        acceptRequest()
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

    // MARK: - Private functions

    private func acceptRequest() {
        firstly {
            self.authorizer.authorize { message in
                DispatchQueue.main.async { [weak self] in
                    self?.pickerView.isHidden = true
                    self?.activityIndicator.startAnimating()
                    if let message = message {
                        self?.progressLabel.isHidden = false
                        self?.progressLabel.text = message
                    }
                }
            }
        }.ensure {
            AuthorizationGuard.shared.authorizationInProgress = false
            self.activityIndicator.stopAnimating()
        }.done(on: .main) { account in
            self.progressLabel.isHidden = true
            if var account = account {
                account.increaseUse()
                NotificationCenter.default.post(name: .accountUpdated, object: self, userInfo: ["account": account])
            }
            self.authenticateButton.isHidden = true
            if self.authorizer.type == .login {
                Properties.loginCount += 1
            }
            if var account = account as? UserAccount, account.hasOtp, let token = try? account.oneTimePasswordToken() {
                if case .counter = token.generator.factor {
                    self.token = token.updatedToken()
                    try account.setOtp(token: self.token!)
                } else {
                    self.token = token
                }
                self.account = account
                self.showOtp()
            } else {
                self.success()
            }
        }.recover(on: .main) { (error) -> Guarantee<Void> in
            guard let errorResponse = error as? ChiffErrorResponse else {
                throw error
            }
            return self.handleChiffErrorResponse(error: errorResponse, siteName: "TODO")
        }.catch(on: .main) { error in
            self.handleError(error: error)
            _ = self.authorizer.cancelRequest(reason: .error, error: nil)
        }
    }

    private func handleChiffErrorResponse(error: ChiffErrorResponse, siteName: String) -> Guarantee<Void> {
        return Guarantee<ChiffErrorResponse> { seal in
            let alert = UIAlertController(title: "requests.authorize_credential_disclosure.title".localized,
                                          message: String(format: "requests.authorize_credential_disclosure.message".localized, siteName),
                                          preferredStyle: .alert)
            alert.addAction(UIAlertAction(title: "requests.authorize_credential_disclosure.allow".localized, style: .default) { _ in
                seal(.discloseAccountExists)
            })
            alert.addAction(UIAlertAction(title: "requests.authorize_credential_disclosure.deny".localized, style: .cancel) { _ in
                seal(.accountExists)
            })
            self.present(alert, animated: true, completion: nil)
        }.then { response in
            return self.authorizer.cancelRequest(reason: .error, error: response)
        }.map {
            self.dismiss()
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
            case .multipleAdminSessionsFound(count: let count):
                self.showAlert(message: String(format: "errors.multiple_admins".localized, count))
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
            if self.authorizer.type == .login &&
                !Properties.hasBeenPromptedReview &&
                (Properties.loginCount % 30 == 0 || Properties.accountCount > 15) {
                SKStoreReviewController.requestReview()
                Properties.hasBeenPromptedReview = true
            } else {
                AuthenticationGuard.shared.hideLockWindow(delay: 0.15)
                self.dismiss()
            }
        }
    }

    private func showSuccessView() {
        self.successView.alpha = 0.0
        self.successView.isHidden = false
        UIView.animate(withDuration: 0.3, delay: 0.0, options: [.curveLinear]) { self.successView.alpha = 1.0 }
    }

    @objc private func applicationDidEnterBackground(notification: Notification) {
       dismiss()
    }

}
