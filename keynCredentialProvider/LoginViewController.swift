/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication
import AuthenticationServices


class LoginViewController: ASCredentialProviderViewController {
    @IBOutlet weak var navigationBar: UINavigationBar!
    @IBOutlet weak var touchIDButton: UIButton!
    var credentialProviderViewController: CredentialProviderViewController?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        navigationBar.shadowImage = UIImage()
        touchIDButton.imageView!.contentMode = .scaleAspectFit
        touchIDButton.imageEdgeInsets = UIEdgeInsets.init(top: 13, left: 13, bottom: 13, right: 13)
        
        if !hasFaceID() {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) { [weak self] in
                self?.authenticateUser()
            }
        }
    }
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    // MARK: - Actions

    @IBAction func touchID(_ sender: UIButton) {
        authenticateUser()
    }
    
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showAccounts", let navCon = segue.destination as? CredentialProviderNavigationController {
            navCon.passedExtensionContext = extensionContext
        }
    }

    // MARK: - AuthenicationServices

    override func prepareCredentialList(for serviceIdentifiers: [ASCredentialServiceIdentifier]) {
        for identifier in serviceIdentifiers {
            do {
                guard let url = URL(string: identifier.identifier), let scheme = url.scheme, let host = url.host else {
                    Logger.shared.debug("Could not decode URL", userInfo: ["url": identifier.identifier])
                    return
                }
                var identities = [ASPasswordCredentialIdentity]()
                for account in try Account.get(siteID: "\(scheme)://\(host)".sha256()) {
                    identities.append(ASPasswordCredentialIdentity(serviceIdentifier: identifier, user: account.username, recordIdentifier: account.id))
                }
                ASCredentialIdentityStore.shared.saveCredentialIdentities(identities, completion: nil)
            } catch {
                Logger.shared.warning("Error getting account", error: error, userInfo: ["url": identifier.identifier])
            }
        }
    }
    
    override func provideCredentialWithoutUserInteraction(for credentialIdentity: ASPasswordCredentialIdentity) {
        do {
            if let account = try Account.get(accountID: credentialIdentity.recordIdentifier!) {
                let passwordCredential = ASPasswordCredential(user: account.username, password: try account.password())
                extensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
            } else {
                extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.credentialIdentityNotFound.rawValue))
            }
        } catch {
            Logger.shared.warning("Error getting account.", error: error)
            extensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
        }
    }

    // MARK: - Authentication
    
    private func authenticateUser() {
        let localAuthenticationContext = LAContext()
        localAuthenticationContext.localizedFallbackTitle = "Use Passcode"
        
        var authError: NSError?
        let reasonString = "Unlock Keyn"
        
        guard localAuthenticationContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            //TODO: Show appropriate alert if biometry/TouchID/FaceID is lockout or not enrolled
            Logger.shared.error(self.evaluateAuthenticationPolicyMessageForLA(errorCode: authError!.code), error: authError)
            return
        }
        
        localAuthenticationContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reasonString)  { [weak self] (succes, error) in
            DispatchQueue.main.async {
                if succes {
                    self?.performSegue(withIdentifier: "showAccounts", sender: self)
                } else if let error = error, let errorCode = authError?.code, let errorMessage = self?.evaluateAuthenticationPolicyMessageForLA(errorCode: errorCode) {
                    Logger.shared.error(errorMessage, error: error)
                    
                    if error._code == LAError.userFallback.rawValue {
                        Logger.shared.debug("TODO: Handle fallback for lack of biometric authentication", error: error)
                    }
                }
            }
        }
    }
    
    private func evaluatePolicyFailErrorMessageForLA(errorCode: Int) -> String {
        var message = ""
        if #available(iOS 11.0, *) {
            switch errorCode {
            case LAError.biometryNotAvailable.rawValue:
                message = "Authentication could not start because the device does not support biometric authentication."
            case LAError.biometryLockout.rawValue:
                message = "Authentication could not continue because the user has been locked out of biometric authentication, due to failing authentication too many times."
            case LAError.biometryNotEnrolled.rawValue:
                message = "Authentication could not start because the user has not enrolled in biometric authentication."
            default:
                message = "Did not find error code on LAError object"
            }
        }
        
        return message
    }
    
    private func evaluateAuthenticationPolicyMessageForLA(errorCode: Int) -> String {
        var message = ""
        
        switch errorCode {
        case LAError.authenticationFailed.rawValue:
            message = "The user failed to provide valid credentials"
        case LAError.appCancel.rawValue:
            message = "Authentication was cancelled by application"
        case LAError.invalidContext.rawValue:
            message = "The context is invalid"
        case LAError.notInteractive.rawValue:
            message = "Not interactive"
        case LAError.passcodeNotSet.rawValue:
            message = "Passcode is not set on the device"
        case LAError.systemCancel.rawValue:
            message = "Authentication was cancelled by the system"
        case LAError.userCancel.rawValue:
            message = "The user did cancel"
        case LAError.userFallback.rawValue:
            message = "The user chose to use the fallback"
        default:
            message = evaluatePolicyFailErrorMessageForLA(errorCode: errorCode)
        }
        
        return message
    }
    
    private func hasFaceID() -> Bool {
        if #available(iOS 11.0, *) {
            let context = LAContext.init()
            var error: NSError?
            if context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: &error) {
                return context.biometryType == LABiometryType.faceID
            }
        }
        
        return false
    }
}
