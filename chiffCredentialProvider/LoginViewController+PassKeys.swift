//
//  LoginViewController+PassKeys.swift
//  chiffCredentialProvider
//
//  Copyright: see LICENSE.md
//

import UIKit
import AuthenticationServices
import LocalAuthentication
import ChiffCore

@available(iOS 17.0, *)
extension LoginViewController {

    override func prepareInterface(forPasskeyRegistration registrationRequest: ASCredentialRequest) {
        guard let request = registrationRequest as? ASPasskeyCredentialRequest,
              let credentialIdentity = request.credentialIdentity as? ASPasskeyCredentialIdentity else {
            return
        }
        self.type = .passkeyRegistration
        let algorithms = request.supportedAlgorithms.compactMap { WebAuthnAlgorithm(rawValue: $0.rawValue) }
        self.passkeyRegistrationRequest = PasskeyRegistrationRequest(clientDataHash: request.clientDataHash,
                                                                     relyingPartyIdentifier: credentialIdentity.relyingPartyIdentifier,
                                                                     userHandle: credentialIdentity.userHandle,
                                                                     userName: credentialIdentity.userName,
                                                                     serviceIdentifier: credentialIdentity.serviceIdentifier,
                                                                     algorithms: algorithms
        )
    }

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier], requestParameters: ASPasskeyCredentialRequestParameters) {
        self.serviceIdentifiers = serviceIdentifiers
        self.type = .passkeyAssertion
        self.passkeyAssertionRequest = PasskeyAssertionRequest(
            clientDataHash: requestParameters.clientDataHash,
            relyingPartyIdentifier: requestParameters.relyingPartyIdentifier
        )
    }

    override func prepareInterfaceToProvideCredential(for credentialRequest: ASCredentialRequest) {
        self.username = credentialRequest.credentialIdentity.user
        self.accountId = credentialRequest.credentialIdentity.recordIdentifier
        switch credentialRequest.type {
        case .passkeyAssertion:
            guard let request = credentialRequest as? ASPasskeyCredentialRequest,
                  let credentialIdentity = request.credentialIdentity as? ASPasskeyCredentialIdentity else {
                return
            }
            self.passkeyAssertionRequest = PasskeyAssertionRequest(clientDataHash: request.clientDataHash, relyingPartyIdentifier: credentialIdentity.relyingPartyIdentifier)
        case .password:
            self.type = .passwordLogin
            self.username = credentialRequest.credentialIdentity.user
            self.accountId = credentialRequest.credentialIdentity.recordIdentifier
        @unknown default:
            self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
        }
    }

    override func provideCredentialWithoutUserInteraction(for credentialRequest: ASCredentialRequest) {
        do {
            switch credentialRequest.type {
            case .passkeyAssertion:
                guard let request = credentialRequest as? ASPasskeyCredentialRequest, let credentialIdentity = request.credentialIdentity as? ASPasskeyCredentialIdentity else {
                    throw NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue)
                }
                guard let account = try UserAccount.getAny(id: credentialIdentity.credentialID.hexEncodedString(), context: nil) as? UserAccount else {
                    return self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.credentialIdentityNotFound.rawValue))
                }
                let assertionRequest = PasskeyAssertionRequest(clientDataHash: request.clientDataHash, relyingPartyIdentifier: credentialIdentity.relyingPartyIdentifier)
                try completeWebauthnAssertion(with: assertionRequest, account: account, context: nil)
            case .password:
                guard let account = try UserAccount.getAny(id: credentialRequest.credentialIdentity.recordIdentifier!, context: nil) else {
                    return self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.credentialIdentityNotFound.rawValue))
                }
                guard let password = try account.password(context: nil) else {
                    return self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.credentialIdentityNotFound.rawValue))
                }
                let passwordCredential = ASPasswordCredential(user: account.username, password: password)
                self.extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
            @unknown default:
                throw NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue)
            }
        } catch KeychainError.interactionNotAllowed {
            self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userInteractionRequired.rawValue))
        } catch {
            self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
        }
    }

    func completeWebauthnAssertion(with assertionRequest: PasskeyAssertionRequest, account: UserAccount, context: LAContext?) throws {
        let signature = try account.webAuthnSign(challenge: assertionRequest.clientDataHash, rpId: assertionRequest.relyingPartyIdentifier)
        let credential = ASPasskeyAssertionCredential(userHandle: account.webAuthn!.userHandle?.data ?? Data(),
                                                      relyingParty: account.webAuthn!.id,
                                                      signature: signature,
                                                      clientDataHash: assertionRequest.clientDataHash,
                                                      authenticatorData: account.webAuthn!.authenticatorData,
                                                      credentialID: account.id.fromHex!)
        self.extensionContext.completeAssertionRequest(using: credential)
    }

    func completePasskeyRegistration(with registrationRequest: PasskeyRegistrationRequest, context: LAContext?) throws {
        guard let site = registrationRequest.serviceIdentifier.site else {
            throw AutofillError.invalidURL
        }
        let webauthn = try WebAuthn(id: registrationRequest.relyingPartyIdentifier,
                                    algorithms: registrationRequest.algorithms,
                                    userHandle: String(data: registrationRequest.userHandle, encoding: .utf8))
        let account = try UserAccount(username: registrationRequest.userName,
                                      sites: [site],
                                      password: nil,
                                      webauthn: webauthn,
                                      notes: nil,
                                      askToChange: false,
                                      context: context)
        let attestationObject = try webauthn.getAttestation(accountId: account.id, extensions: nil)
        let credential = ASPasskeyRegistrationCredential(relyingParty: webauthn.id,
                                                         clientDataHash: registrationRequest.clientDataHash,
                                                         credentialID: account.id.fromHex!,
                                                         attestationObject: attestationObject)
        self.extensionContext.completeRegistrationRequest(using: credential)
    }
}
