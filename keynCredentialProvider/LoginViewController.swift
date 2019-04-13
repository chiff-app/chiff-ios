/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication
import AuthenticationServices

class LoginViewController: ASCredentialProviderViewController {
    @IBOutlet weak var touchIDButton: UIButton!
    @IBOutlet weak var requestLabel: UILabel!
    var credentialProviderViewController: CredentialProviderViewController?
    var shouldAsk: Bool = false
    var credentialIdentity: ASPasswordCredentialIdentity?
    var accounts: [String: Account]!

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let username = credentialIdentity?.user {
            requestLabel.text = "\("requests.login_with".localized) \(username)"
        } else {
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
        if let destination = segue.destination.contents as? CredentialProviderViewController {
            destination.unfilteredAccounts = Array(accounts.values)
            destination.credentialExtensionContext = extensionContext
        }
    }

    // MARK: - AuthenicationServices

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        do {
            guard let account = try Account.get(accountID: credentialIdentity.recordIdentifier!, context: nil) else {
                return self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.credentialIdentityNotFound.rawValue))
            }
            
            let passwordCredential = ASPasswordCredential(user: account.username, password: try account.password(context: nil))
            self.extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
        } catch KeychainError.interactionNotAllowed {
            self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userInteractionRequired.rawValue))
        } catch {
            self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
        }
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        self.credentialIdentity = credentialIdentity
    }

    // MARK: - Private functions

    private func loadUsers() {
        let reason = credentialIdentity != nil ? "\("requests.login_with".localized) \(credentialIdentity!.user)" : "requests.unlock_accounts".localized
        LocalAuthenticationManager.shared.authenticate(reason: reason, withMainContext: true) { (context, error) in
            do {
                if let error = error {
                    throw error
                }
                if let accountID = self.credentialIdentity?.recordIdentifier, let account = try Account.get(accountID: accountID, context: context) {
                    let passwordCredential = ASPasswordCredential(user: account.username, password: try account.password(context: context))
                    self.extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
                } else {
                    let accounts = try Account.all(context: context)
                    guard !accounts.isEmpty else {
                        self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
                        return
                    }
                    DispatchQueue.main.async {
                        self.accounts = accounts
                        self.performSegue(withIdentifier: "showAccounts", sender: self)
                    }
                }
            } catch {
                self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
            }
        }
    }
}
