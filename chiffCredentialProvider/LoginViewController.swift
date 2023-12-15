//
//  LoginViewController.swift
//  chiffCredentialProvider
//
//  Copyright: see LICENSE.md
//

import UIKit
import LocalAuthentication
import AuthenticationServices
import PromiseKit
import ChiffCore

enum AutofillError: Error {
    case invalidURL
}

enum AutoFillRequestType {
    case passkeyAssertion
    case passkeyRegistration
    case passwordLogin
    case passwordRegistration
}

class LoginViewController: ASCredentialProviderViewController {
    @IBOutlet weak var touchIDButton: UIButton!
    @IBOutlet weak var requestLabel: UILabel!
    var credentialProviderViewController: CredentialProviderViewController?
    var shouldAsk: Bool = false
    var serviceIdentifiers: [ASCredentialServiceIdentifier]!
    var type: AutoFillRequestType!
    var accounts: [String: Account]!
    var accountId: String?
    var username: String?
    var passkeyRegistrationRequest: PasskeyRegistrationRequest?
    var passkeyAssertionRequest: PasskeyAssertionRequest?

    override func viewDidLoad() {
        super.viewDidLoad()
        ChiffCore.initialize(logger: ChiffLogger(enableOutOfMemoryTracking: false), localizer: ChiffLocalizer())
        if Properties.hasFaceID {
            touchIDButton.setImage(UIImage(named: "face_id"), for: .normal)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        switch type {
        case .passkeyRegistration:
            requestLabel.text = String(format: "requests.add_site".localized, passkeyRegistrationRequest!.relyingPartyIdentifier)
        case .passkeyAssertion:
            requestLabel.text = String(format: "requests.login_to".localized, passkeyAssertionRequest!.relyingPartyIdentifier)
        case .passwordLogin:
            requestLabel.text = String(format: "requests.login_with".localized, username!)
        default:
            requestLabel.text = "requests.unlock_accounts".localized
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadUsers()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    // MARK: - Actions

    @IBAction func cancel(_ sender: UIButton) {
        extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowAccounts", let destination = segue.destination.contents as? CredentialProviderViewController {
            destination.unfilteredAccounts = Array(accounts.values)
            destination.serviceIdentifiers = self.serviceIdentifiers
            destination.credentialExtensionContext = extensionContext
        } else if segue.identifier == "ShowAddAccount", let destination = segue.destination.contents as? AddAccountViewController {
            destination.serviceIdentifiers = self.serviceIdentifiers
            destination.credentialExtensionContext = extensionContext
        }
    }

    // MARK: - Private functions

    private func loadUsers() {
        let reason = username != nil ? String(format: "requests.login_with".localized, username!) : "requests.unlock_accounts".localized
        firstly {
            LocalAuthenticationManager.shared.authenticate(reason: reason, withMainContext: true)
        }.done { context in
            switch self.type {
            case .passkeyRegistration:
                guard #available(iOS 17.0, *), let passkeyRegistrationRequest = self.passkeyRegistrationRequest else {
                    return self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
                }
                try self.completePasskeyRegistration(with: passkeyRegistrationRequest, context: context)
            case .passkeyAssertion:
                guard #available(iOS 17.0, *), let passkeyAssertionRequest = self.passkeyAssertionRequest else {
                    return self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
                }
                guard let accountID = self.accountId, let account = try UserAccount.getAny(id: accountID, context: context) as? UserAccount else {
                    let accounts = try UserAccount.all(context: context).filter { $1.webAuthn != nil }
                    DispatchQueue.main.async {
                        self.accounts = accounts
                        self.performSegue(withIdentifier: "ShowAccounts", sender: self)
                    }
                    return
                }
                try self.completeWebauthnAssertion(with: passkeyAssertionRequest, account: account, context: context)
            case .passwordLogin:
                guard let accountID = self.accountId, let account = try UserAccount.getAny(id: accountID, context: context) else {
                    let accounts = try UserAccount.allCombined(context: context)
                    DispatchQueue.main.async {
                        if accounts.isEmpty {
                            self.performSegue(withIdentifier: "ShowAddAccount", sender: self)
                        } else {
                            self.accounts = accounts
                            self.performSegue(withIdentifier: "ShowAccounts", sender: self)
                        }
                    }
                    return
                }
                try self.completePasswordLoginRequest(account: account, context: context)
            default:
                self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.credentialIdentityNotFound.rawValue))
            }
        }.catch { _ in
            self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
        }
    }

}
