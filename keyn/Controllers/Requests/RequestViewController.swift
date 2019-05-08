/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication

class RequestViewController: UIViewController {

    @IBOutlet weak var requestLabel: UILabel!
    @IBOutlet weak var successView: UIStackView!
    @IBOutlet weak var successTextLabel: UILabel!
    @IBOutlet weak var successTextDetailLabel: UILabel!

    var authorizationGuard: AuthorizationGuard!

    private var authorized = false
    private var accounts = [Account]()

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
        authorizationGuard.acceptRequest { error in
            DispatchQueue.main.async {
                if let error = error {
                    if let errorMessage = LocalAuthenticationManager.shared.handleError(error: error) {
                        self.showError(message: errorMessage)
                        Logger.shared.error("Error authorizing request", error: error)
                    }
                } else {
                    self.success()
                }
            }
        }
    }

    private func success() {
        switch authorizationGuard.type {
            case .login:
                successTextLabel.text = "requests.login_succesful".localized.capitalizedFirstLetter
                successTextDetailLabel.text = "requests.return_to_computer".localized.capitalizedFirstLetter
            case .addAndLogin:
                successTextLabel.text = "requests.account_added".localized.capitalizedFirstLetter
                successTextDetailLabel.text = "requests.return_to_computer".localized.capitalizedFirstLetter
            case .add, .addToExisting:
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
        self.successView.alpha = 0.0
        self.successView.isHidden = false
        self.authorized = true
        UIView.animate(withDuration: 0.3, delay: 0.0, options: [.curveLinear], animations: { self.successView.alpha = 1.0 })
        DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
            self.dismiss(animated: true, completion: nil)
            AuthenticationGuard.shared.hideLockWindow()
        }
    }

    // MARK: - Actions

    @IBAction func authenticate(_ sender: UIButton) {
        acceptRequest()
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
