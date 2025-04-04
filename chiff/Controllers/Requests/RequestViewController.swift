//
//  RequestViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import ChiffCore
import LocalAuthentication
import OneTimePassword
import PromiseKit
import StoreKit
import UIKit

class RequestViewController: UIViewController, UIAdaptivePresentationControllerDelegate {
    @IBOutlet var requestLabel: UILabel!
    @IBOutlet var successView: BackupCircle!
    @IBOutlet var successTextLabel: UILabel!
    @IBOutlet var successTextDetailLabel: UILabel!
    @IBOutlet var checkmarkHeightContstraint: NSLayoutConstraint!
    @IBOutlet var authenticateButton: UIButton!
    @IBOutlet var progressLabel: UILabel!
    @IBOutlet var successImageView: UIImageView!
    @IBOutlet var activityIndicator: UIActivityIndicatorView!
    @IBOutlet var pickerView: UIPickerView!

    var authorizer: Authorizer!

    private var authorized = false
    private var accounts = [Account]()
    private var account: Account?
    private var otpCodeTimer: Timer?
    private var token: Token?
    private var showAuthorizationAlert = false
    lazy var teamSessions: [TeamSession] = {
        (try? TeamSession.all().filter { $0.isAdmin }) ?? []
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        if Properties.hasFaceID {
            showAuthorizationAlert = authorizer.verify || !Properties.autoShowAuthorization
            authenticateButton.setImage(UIImage(named: "face_id"), for: .normal)
        }
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(applicationDidEnterBackground(notification:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        pickerView.dataSource = self
        pickerView.delegate = self
        if #available(iOS 13.0, *) {
            isModalInPresentation = true
            presentationController?.delegate = self
        }
        requestLabel.text = authorizer.requestText
        if authorizer is TeamAdminLoginAuthorizer, !teamSessions.isEmpty {
            (authorizer as? TeamAdminLoginAuthorizer)?.teamSession = teamSessions.first
            if teamSessions.count > 1 {
                pickerView.isHidden = false
                showAuthorizationAlert = false
                requestLabel.text = "requests.pick_team".localized
                progressLabel.isHidden = false
                progressLabel.text = "requests.click_authorize_button".localized
                return
            }
        }
        if !showAuthorizationAlert {
            acceptRequest(code: nil)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard showAuthorizationAlert else { return }
        showAuthorizationAlert = false
        showAlert()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    func presentationControllerDidAttemptToDismiss(_ presentationController: UIPresentationController) {
        cancelRequest()
    }

    // MARK: - Actions

    @IBAction func authenticate(_ sender: UIButton) {
        AuthorizationGuard.shared.authorizationInProgress = true
        acceptRequest(code: nil)
    }

    @IBAction func close(_ sender: UIButton) {
        cancelRequest()
    }


    // MARK: - Navigation

    func dismiss() {
        presentingViewController?.dismiss(animated: true, completion: nil) ?? dismiss(animated: true, completion: nil)
    }

    // MARK: - Private functions

    private func cancelRequest() {
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

    private func showAlert() {
        let alert = UIAlertController(title: authorizer.requestText,
                                      message: authorizer.verify ? authorizer.verifyText : authorizer.authenticationReason,
                                      preferredStyle: authorizer.verify ? .alert : .actionSheet)
        if authorizer.verify {
            alert.addTextField { textField in
                textField.placeholder = "123456"
                textField.keyboardType = .numberPad
                textField.textContentType = .oneTimeCode
                textField.delegate = self
            }
            alert.addAction(UIAlertAction(title: "popups.responses.deny".localized, style: .destructive) { _ in
                AuthorizationGuard.shared.authorizationInProgress = false
            })
            alert.addAction(UIAlertAction(title: "popups.responses.authorize".localized, style: .default) { _ in
                self.acceptRequest(code: alert.textFields?[0].text)
            })
        } else {
            alert.addAction(UIAlertAction(title: "popups.responses.authorize".localized, style: .default) { _ in
                self.acceptRequest(code: nil)
            })
            alert.addAction(UIAlertAction(title: "popups.responses.deny".localized, style: .destructive) { _ in
                AuthorizationGuard.shared.authorizationInProgress = false
            })
        }
        present(alert, animated: true, completion: nil)
    }

    private func acceptRequest(code: String?) {
        AuthorizationGuard.shared.authorizationInProgressSemaphore.wait()
        firstly {
            self.authorizer.authorize(verification: code) { message in
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
            AuthorizationGuard.shared.authorizationInProgressSemaphore.signal()
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
            return self.handleChiffErrorResponse(error: errorResponse, siteName: (self.authorizer as? LoginAuthorizer)?.siteName ?? "website")
        }.catch(on: .main) { error in
            if self.handleError(error: error) {
                _ = self.authorizer.cancelRequest(reason: .error, error: nil)
            }
        }
    }

    private func handleChiffErrorResponse(error: ChiffErrorResponse, siteName: String) -> Guarantee<Void> {
        switch error {
        case .accountExists, .discloseAccountExists:
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
                self.authorizer.cancelRequest(reason: .error, error: response)
            }.map {
                self.dismiss()
            }
        default:
            return firstly {
                self.authorizer.cancelRequest(reason: .error, error: error)
            }.map {
                self.dismiss()
            }
        }

    }

    private func handleError(error: Error) -> Bool {
        if let error = error as? AuthorizationError {
            switch error {
            case .inProgress, .missingData, .unknownType:
                return true
            default:
                showAlert(message: error.localizedDescription)
            }
            AuthenticationGuard.shared.hideLockWindow()
        } else if let error = error as? APIError {
            Logger.shared.error("APIError authorizing request", error: error)
            guard authorizer.type == .createOrganisation else {
                showAlert(message: error.localizedDescription)
                return true
            }
            showAlert(message: error.localizedDescription)
        } else if let error = error as? PasswordGenerationError {
            showAlert(message: error.localizedDescription)
        } else if case AccountError.importError(failed: _, total: _) = error {
            self.showAlert(message: error.localizedDescription) { _ in
                self.dismiss()
                AuthenticationGuard.shared.hideLockWindow()
            }
        } else if let errorMessage = LocalAuthenticationManager.shared.handleError(error: error) {
            showAlert(message: errorMessage)
            Logger.shared.error("Error authorizing request", error: error)
        } else {
            switch error {
            case KeychainError.authenticationCancelled, LAError.appCancel, LAError.systemCancel, LAError.userCancel:
                return false
            default:
                Logger.shared.error("Error authorizing request", error: error)
                return true
            }
        }
        return true
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
            otpCodeTimer = Timer.scheduledTimer(withTimeInterval: period - start, repeats: false, block: { _ in
                self.successTextLabel.text = self.token!.currentPasswordSpaced
                self.otpCodeTimer = Timer.scheduledTimer(timeInterval: period, target: self, selector: #selector(self.updateTOTP), userInfo: nil, repeats: true)
            })
            successView.startCircleAnimation(duration: period, start: start)
        }
        successTextDetailLabel.text = "requests.enter_otp".localized
        authorized = true
        showSuccessView()
    }

    @objc func updateTOTP() {
        successTextLabel.text = token?.currentPasswordSpaced ?? ""
    }

    private func success() {
        successTextLabel.text = authorizer.successText
        successTextDetailLabel.text = authorizer.succesDetailText
        authorized = true
        showSuccessView()
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
        successView.alpha = 0.0
        successView.isHidden = false
        UIView.animate(withDuration: 0.3, delay: 0.0, options: [.curveLinear]) { self.successView.alpha = 1.0 }
    }

    @objc private func applicationDidEnterBackground(notification: Notification) {
        dismiss()
    }
}

extension RequestViewController: UITextFieldDelegate {

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        // Handle backspace/delete
        guard !string.isEmpty else {

            // Backspace detected, allow text change, no need to process the text any further
            return true
        }
        return CharacterSet.decimalDigits.isSuperset(of: CharacterSet(charactersIn: string))
    }
}

