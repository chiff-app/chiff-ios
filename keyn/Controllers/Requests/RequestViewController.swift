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

    private var accounts = [Account]()

    override func viewDidLoad() {
        super.viewDidLoad()
        switch authorizationGuard.type {
        case .login:
            requestLabel.text = "requests.confirm_login".localized.capitalized
        case .add, .addAndLogin:
            requestLabel.text = "requests.add_account".localized.capitalized
        case .addBulk:
            requestLabel.text = "requests.add_accounts".localized.capitalized
        case .change:
            requestLabel.text = "requests.change_password".localized.capitalized
        case .fill:
            requestLabel.text = "requests.fill_password".localized.capitalized
        default:
            requestLabel.text = "requests.unknown_request".localized.capitalized
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
                    self.showError(message: "\("errors.authentication_error".localized): \(error)")
                } else {
                    self.success()
                }
            }
        }
    }

    private func success() {
        switch authorizationGuard.type {
            case .login:
                successTextLabel.text = "requests.login_succesful".localized.capitalized
                successTextDetailLabel.text = "requests.return_to_computer".localized.capitalized
            case .addAndLogin:
                successTextLabel.text = "requests.account_added".localized.capitalized
                successTextDetailLabel.text = "requests.return_to_computer".localized.capitalized
            case .add:
                successTextLabel.text = "requests.account_added".localized.capitalized
                successTextDetailLabel.text = "requests.login_keyn_next_time".localized.capitalized
            case .addBulk:
                successTextLabel.text = "\(authorizationGuard.accounts.count) \("requests.accounts_added".localized)"
                successTextDetailLabel.text = "requests.login_keyn_next_time".localized.capitalized
            case .change:
                successTextLabel.text = "requests.new_password_generated".localized.capitalized
                successTextDetailLabel.text = "\("requests.return_to_computer".localized.capitalized) \("requests.to_complete_process".localized)"
            case .fill:
                successTextLabel.text = "requests.fill_password_successful".localized.capitalized
                successTextDetailLabel.text = "requests.return_to_computer".localized.capitalized
            default:
                requestLabel.text = "requests.unknown_request".localized.capitalized
        }
        self.successView.alpha = 0.0
        self.successView.isHidden = false
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
        authorizationGuard.rejectRequest() {
            DispatchQueue.main.async {
                self.dismiss(animated: true, completion: nil)
            }
        }
    }
}
