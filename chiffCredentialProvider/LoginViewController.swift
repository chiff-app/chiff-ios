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

class LoginViewController: ASCredentialProviderViewController {
    @IBOutlet weak var touchIDButton: UIButton!
    @IBOutlet weak var requestLabel: UILabel!
    var credentialProviderViewController: CredentialProviderViewController?
    var shouldAsk: Bool = false
    var serviceIdentifiers: [ASCredentialServiceIdentifier]!
    var accounts: [String: Account]!
    var accountId: String?
    var username: String?
    var clientDataHash: Data?

    override func viewDidLoad() {
        super.viewDidLoad()
        ChiffCore.initialize(logger: ChiffLogger(enableOutOfMemoryTracking: false), localizer: ChiffLocalizer())
        if Properties.hasFaceID {
            touchIDButton.setImage(UIImage(named: "face_id"), for: .normal)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let username = self.username {
            requestLabel.text = String(format: "requests.login_with".localized, username)
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
            if #available(iOS 17.0, *), let clientDataHash = self.clientDataHash, let userAccount = account as? UserAccount {
                try self.completeWebauthnAssertion(context: context, clientDataHash: clientDataHash, account: userAccount)
            } else if let password = try account.password(context: context) {
                let passwordCredential = ASPasswordCredential(user: account.username, password: password)
                self.extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
            } else {
                self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.credentialIdentityNotFound.rawValue))
            }
        }.catch { _ in
            self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
        }
    }
}


extension LoginViewController {
    
    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        self.username = credentialIdentity.user
        self.accountId = credentialIdentity.recordIdentifier
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        self.serviceIdentifiers = serviceIdentifiers
    }
    
    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        do {
            guard let account = try UserAccount.getAny(id: credentialIdentity.recordIdentifier!, context: nil), let password = try account.password(context: nil) else {
                return self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.credentialIdentityNotFound.rawValue))
            }

            let passwordCredential = ASPasswordCredential(user: account.username, password: password)
            self.extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
        } catch KeychainError.interactionNotAllowed {
            self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userInteractionRequired.rawValue))
        } catch {
            self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
        }
    }
}

@available(iOSApplicationExtension 17.0, *)
extension LoginViewController {
    
//    override func prepareInterface(forPasskeyRegistration registrationRequest: ASCredentialRequest) {
//        
//    }
//    
    override func prepareInterfaceToProvideCredential(for credentialRequest: ASCredentialRequest) {
        self.username = credentialRequest.credentialIdentity.user
        self.accountId = credentialRequest.credentialIdentity.recordIdentifier
        print(credentialRequest.credentialIdentity.serviceIdentifier.identifier)
        if credentialRequest.type == .passkeyAssertion, let request = credentialRequest as? ASPasskeyCredentialRequest {
            self.clientDataHash = request.clientDataHash
        }
    }
    
//    override func provideCredentialWithoutUserInteraction(for credentialRequest: ASCredentialRequest) {
//        <#code#>
//    }
    
    func completeWebauthnAssertion(context: LAContext, clientDataHash: Data, account: UserAccount) throws {
        // TODO, check if we can use the serviceIdentifier for this..
        let signature = try account.webAuthnSign(challenge: clientDataHash, rpId: account.webAuthn!.id)
        let credential = ASPasskeyAssertionCredential(userHandle: account.webAuthn!.userHandle?.data ?? Data(), relyingParty: account.webAuthn!.id, signature: signature, clientDataHash: clientDataHash, authenticatorData: account.webAuthn!.authenticatorData, credentialID: account.id.fromHex!)
        self.extensionContext.completeAssertionRequest(using: credential)
    }
}
