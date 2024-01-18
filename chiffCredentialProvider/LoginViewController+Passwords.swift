//
//  LoginViewController+Passwords.swift
//  chiffCredentialProvider
//
//  Copyright: see LICENSE.md
//

import UIKit
import AuthenticationServices
import LocalAuthentication
import ChiffCore

extension LoginViewController {

    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
        self.type = .passwordLogin
        self.username = credentialIdentity.user
        self.accountId = credentialIdentity.recordIdentifier
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        self.type = .passwordLogin
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

    func completePasswordLoginRequest(account: Account, context: LAContext) throws {
        guard let password = try account.password(context: context) else {
            return self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.credentialIdentityNotFound.rawValue))
        }
        let passwordCredential = ASPasswordCredential(user: account.username, password: password)
        self.extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
    }
}
