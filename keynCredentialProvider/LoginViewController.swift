/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication
import AuthenticationServices

struct Extension {
    static var localAuthenticationContext = LAContext()
    static var extensionContext: ASCredentialProviderExtensionContext!
}

class LoginViewController: ASCredentialProviderViewController {
    @IBOutlet weak var touchIDButton: UIButton!
    var credentialProviderViewController: CredentialProviderViewController?
    var shouldAsk: Bool = false
    var credentialIdentity: ASPasswordCredentialIdentity?

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        LocalAuthenticationManager.shared.unlock(reason: "requests.unlock_accounts".localized) { (result, error) in
            DispatchQueue.main.async {
                if result {
                    self.performSegue(withIdentifier: "showAccounts", sender: self)
                } else {
                    self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
                }
            }
        }
//        loadUsers()
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
        Extension.extensionContext = extensionContext
    }

    // MARK: - AuthenicationServices

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        do {
            guard let account = try Account.get(accountID: credentialIdentity.recordIdentifier!, context: Extension.localAuthenticationContext) else {
                return self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userInteractionRequired.rawValue))
            }

            guard let password = try? account.password(context: Extension.localAuthenticationContext) else {
                return self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userInteractionRequired.rawValue))
            }

            let passwordCredential = ASPasswordCredential(user: account.username, password: password)
            self.extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
        } catch {
            self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
        }
    }

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        self.credentialIdentity = credentialIdentity
        #warning("TODO: Change 'Unlock Keyn' in UI to 'Login to website x'")
    }

    // MARK: - Private functions

    private func loadUsers() {
        do {
            if let credentialIdentity = self.credentialIdentity {
                #warning("TODO: Check if this needs to be async")
                guard let account = try Account.get(accountID: credentialIdentity.recordIdentifier!, context: Extension.localAuthenticationContext) else {
                    return self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.credentialIdentityNotFound.rawValue))
                }
                let password = try account.password(context: Extension.localAuthenticationContext)
                let passwordCredential = ASPasswordCredential(user: account.username, password: password)
                self.extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
            } else {
                Extension.localAuthenticationContext = LAContext()
                Account.all(reason: "requests.unlock_accounts".localized, type: .ifNeeded, context: Extension.localAuthenticationContext) { (accounts, error) in
                    DispatchQueue.main.async {
                        if let accounts = accounts, !accounts.isEmpty {
                                self.performSegue(withIdentifier: "showAccounts", sender: self)
                        } else {
                            self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
                        }
                    }
                }
            }
        } catch {
            self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
        }
    }
}
