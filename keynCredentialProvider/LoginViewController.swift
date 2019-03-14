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
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var touchIDButton: UIButton!
    var credentialProviderViewController: CredentialProviderViewController?
    var shouldAsk: Bool = false
    var credentialIdentity: ASPasswordCredentialIdentity?

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationBar.shadowImage = UIImage()
        touchIDButton.imageView!.contentMode = .scaleAspectFit
        touchIDButton.imageEdgeInsets = UIEdgeInsets.init(top: 13, left: 13, bottom: 13, right: 13)

    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        loadUsers()
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    // MARK: - Actions

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        Extension.extensionContext = extensionContext
    }

    // MARK: - AuthenicationServices

    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        do {
            let accounts = try Account.loadAll(context: Extension.localAuthenticationContext, reason: "Login with \(credentialIdentity.user)", skipAuthenticationUI: true)

            guard let account = accounts[credentialIdentity.recordIdentifier!] else {
                return self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userInteractionRequired.rawValue))
            }

            guard let password = try? account.password(reason: "Get password for \(account.site.name)", context: Extension.localAuthenticationContext, skipAuthenticationUI: true) else {
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
        DispatchQueue.global(qos: .userInteractive).async {
            do {
                if let credentialIdentity = self.credentialIdentity {
                    let accounts = try Account.loadAll(context: Extension.localAuthenticationContext, reason: "Login with \(credentialIdentity.user)", skipAuthenticationUI: false)
                    guard let account = accounts[credentialIdentity.recordIdentifier!] else {
                        return self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.credentialIdentityNotFound.rawValue))
                    }

                    let password = try account.password(reason: "Login to \(account.site.name)", context: Extension.localAuthenticationContext, skipAuthenticationUI: false)

                    let passwordCredential = ASPasswordCredential(user: account.username, password: password)
                    self.extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
                } else {
                    Extension.localAuthenticationContext = LAContext()
                    let accounts = try Account.loadAll(context: Extension.localAuthenticationContext, reason: "Unlock Keyn", skipAuthenticationUI: false)
                    if !accounts.isEmpty {
                        DispatchQueue.main.async {
                            self.performSegue(withIdentifier: "showAccounts", sender: self)
                        }
                    } else {
                        self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
                    }
                }
            } catch {
                self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
            }
        }
    }
}
