//
//  CredentialProviderViewController.swift
//  keynCredentialProvider
//
//  Created by bas on 17/07/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import AuthenticationServices
import LocalAuthentication
import JustLog

class CredentialProviderViewController: ASCredentialProviderViewController {
    /*
     Prepare your UI to list available credentials for the user to choose from. The items in
     'serviceIdentifiers' describe the service the user is logging in to, so your extension can
     prioritize the most relevant credentials in the
     */
    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        for identifier in serviceIdentifiers {
            do {
                guard let url = URL(string: identifier.identifier), let scheme = url.scheme, let host = url.host else {
                    print("Could not parse URL")
                    return
                }
                var identities = [ASPasswordCredentialIdentity]()
                for account in try Account.get(siteID: "\(scheme)://\(host)".sha256()) {
                    identities.append(ASPasswordCredentialIdentity(serviceIdentifier: identifier, user: account.username, recordIdentifier: account.id))
                }
                ASCredentialIdentityStore.shared.saveCredentialIdentities(identities, completion: nil)
            } catch {
                print(error)
            }
        }
    }
    
    /*
     Implement this method if your extension supports showing credentials in the QuickType bar.
     When the user selects a credential from your app, this method will be called with the
     ASPasswordCredentialIdentity your app has previously saved to the ASCredentialIdentityStore.
     Provide the password by completing the extension request with the associated ASPasswordCredential.
     If using the credential would require showing custom UI for authenticating the user, cancel
     the request with error code ASExtensionError.userInteractionRequired.
     */
    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        do {
            if let account = try Account.get(accountID: credentialIdentity.recordIdentifier!) {
                let passwordCredential = ASPasswordCredential(user: account.username, password: try account.password())
                extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
            } else {
                extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.credentialIdentityNotFound.rawValue))
            }
        } catch {
            Logger.shared.warning("Error getting account.", error: error as NSError)
            extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
        }
    }
    
    
    /*
     Implement this method if provideCredentialWithoutUserInteraction(for:) can fail with
     ASExtensionError.userInteractionRequired. In this case, the system may present your extension's
     UI and call this method. Show appropriate UI for authenticating the user then provide the password
     by completing the extension request with the associated ASPasswordCredential.
     */
//    override func prepareInterfaceToProvideCredential(for credentialIdentity: ASPasswordCredentialIdentity) {
//        authenticateUser()
//    }
    
    
    @IBAction func cancel(_ sender: AnyObject?) {
        self.extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.userCanceled.rawValue))
    }
    
//
//    private func authenticateUser() {
//        let localAuthenticationContext = LAContext()
//        localAuthenticationContext.localizedFallbackTitle = "Use Passcode"
//
//        var authError: NSError?
//        let reasonString = "Unlock Keyn"
//
//        guard localAuthenticationContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
//            Logger.shared.error(self.evaluateAuthenticationPolicyMessageForLA(errorCode: authError!.code), error: authError)
//            return
//        }
//
//        localAuthenticationContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reasonString)  { [weak self] (succes, error) in
//            if succes {
//                self?.hideLockWindow()
//            } else if let error = error, let errorCode = authError?.code, let errorMessage = self?.evaluateAuthenticationPolicyMessageForLA(errorCode: errorCode) {
//                Logger.shared.error(errorMessage, error: error as NSError)
//                if error._code == LAError.userFallback.rawValue {
//                    Logger.shared.debug("TODO: Handle fallback for lack of biometric authentication", error: error as NSError)
//                }
//            }
//        }
//    }
//
//    func evaluatePolicyFailErrorMessageForLA(errorCode: Int) -> String {
//        var message = ""
//        if #available(iOS 11.0, *) {
//            switch errorCode {
//            case LAError.biometryNotAvailable.rawValue:
//                message = "Authentication could not start because the device does not support biometric authentication."
//            case LAError.biometryLockout.rawValue:
//                message = "Authentication could not continue because the user has been locked out of biometric authentication, due to failing authentication too many times."
//            case LAError.biometryNotEnrolled.rawValue:
//                message = "Authentication could not start because the user has not enrolled in biometric authentication."
//            default:
//                message = "Did not find error code on LAError object"
//            }
//        }
//
//        return message
//    }
//
//
//    func evaluateAuthenticationPolicyMessageForLA(errorCode: Int) -> String {
//
//        var message = ""
//
//        switch errorCode {
//        case LAError.authenticationFailed.rawValue:
//            message = "The user failed to provide valid credentials"
//        case LAError.appCancel.rawValue:
//            message = "Authentication was cancelled by application"
//        case LAError.invalidContext.rawValue:
//            message = "The context is invalid"
//        case LAError.notInteractive.rawValue:
//            message = "Not interactive"
//        case LAError.passcodeNotSet.rawValue:
//            message = "Passcode is not set on the device"
//        case LAError.systemCancel.rawValue:
//            message = "Authentication was cancelled by the system"
//        case LAError.userCancel.rawValue:
//            message = "The user did cancel"
//        case LAError.userFallback.rawValue:
//            message = "The user chose to use the fallback"
//        default:
//            message = evaluatePolicyFailErrorMessageForLA(errorCode: errorCode)
//        }
//
//        return message
//    }
//
}
