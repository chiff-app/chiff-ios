//
//  AuthenticationGuard.swift
//  keyn
//
//  Created by bas on 17/04/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UIKit
import LocalAuthentication

class AuthenticationGuard {
    
    static let sharedInstance = AuthenticationGuard()
    private let lockWindow: UIWindow
    
    private init() {
        lockWindow = UIWindow(frame: UIScreen.main.bounds)
        lockWindow.windowLevel = UIWindowLevelAlert
        lockWindow.screen = UIScreen.main
        
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSNotification.Name.UIApplicationDidEnterBackground, object: nil, queue: OperationQueue.main, using: <#T##(Notification) -> Void#>)
        
    }
    
    func authenticateUser() {
        
        let localAuthenticationContext = LAContext()
        localAuthenticationContext.localizedFallbackTitle = "Use Passcode"
        
        var authError: NSError?
        let reasonString = "Unlock Keyn"
        
        guard localAuthenticationContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            //TODO: Show appropriate alert if biometry/TouchID/FaceID is lockout or not enrolled
            print(self.evaluateAuthenticationPolicyMessageForLA(errorCode: authError!.code))
            return
        }
        localAuthenticationContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reasonString) { success, evaluateError in
            
            if success {
                DispatchQueue.main.async {
                    let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
                    let viewController = storyboard.instantiateViewController(withIdentifier: "RootController") as! RootViewController
                    UIApplication.shared.keyWindow?.rootViewController = viewController
                }
            } else {
                //TODO: User did not authenticate successfully, look at error and take appropriate action
                guard let error = evaluateError else {
                    return
                }
                
                print(self.evaluateAuthenticationPolicyMessageForLA(errorCode: error._code))
                //TODO: If you have choosen the 'Fallback authentication mechanism selected' (LAError.userFallback). Handle gracefully
                if error._code == LAError.userFallback.rawValue {
                    print("Handle fallback")
                }
                
            }
        }
    }
    
    func authorizeRequest(site: Site, type: BrowserMessageType, completion: @escaping (_: Bool, _: Error?)->()) {
        let authenticationContext = LAContext()
        var error: NSError?
        
        var localizedReason = ""
        switch type {
        case .add, .addAndChange:
            localizedReason = "Add \(site.name)"
        case .change:
            localizedReason = "Change password for \(site.name)"
        case .login:
            localizedReason = "Login to \(site.name)"
        case .reset:
            localizedReason = "Reset password for \(site.name)"
        case .register:
            localizedReason = "Register for \(site.name)"
        default:
            localizedReason = "\(site.name)"
        }
        
        guard authenticationContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            print("Todo: handle fingerprint absence \(String(describing: error))")
            return
        }
        
        authenticationContext.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: localizedReason,
            reply: completion
        )
    }
    
    
    
    func evaluatePolicyFailErrorMessageForLA(errorCode: Int) -> String {
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
    
    
    func evaluateAuthenticationPolicyMessageForLA(errorCode: Int) -> String {
        
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
    
    
}
