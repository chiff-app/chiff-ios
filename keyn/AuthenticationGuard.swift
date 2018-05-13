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
    private let lockViewTag = 390847239047
    var authorizationInProgress = false
    var authenticationInProgress = false
    
    private init() {
        lockWindow = UIWindow(frame: UIScreen.main.bounds)
        lockWindow.windowLevel = UIWindowLevelAlert
        lockWindow.screen = UIScreen.main
        
        let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        lockWindow.rootViewController = storyboard.instantiateViewController(withIdentifier: "LoginController") as! LoginViewController
        
        let nc = NotificationCenter.default
        nc.addObserver(forName: NSNotification.Name.UIApplicationDidEnterBackground, object: nil, queue: OperationQueue.main, using: applicationDidEnterBackground)
        nc.addObserver(forName: NSNotification.Name.UIApplicationDidFinishLaunching, object: nil, queue: OperationQueue.main, using: didFinishLaunchingWithOptions)
        nc.addObserver(forName: NSNotification.Name.UIApplicationWillEnterForeground, object: nil, queue: OperationQueue.main, using: applicationWillEnterForeground)
        nc.addObserver(forName: NSNotification.Name.UIApplicationDidBecomeActive, object: nil, queue: OperationQueue.main, using: applicationDidBecomeActive)
    }
    
    func hideLockWindow() {
        UIView.animate(withDuration: 0.25, animations: {
            self.lockWindow.alpha = 0.0
        }) { if $0 {
            self.lockWindow.isHidden = true
            self.lockWindow.alpha = 1.0
            self.authenticationInProgress = false
            }
        }
    }
    
    // MARK: UIApplication Notification Handlers
    
    private func applicationWillEnterForeground(notification: Notification) {
        if let lockView = lockWindow.viewWithTag(lockViewTag) {
            lockView.removeFromSuperview()
        }
    }
    
    private func applicationDidBecomeActive(notification: Notification) {
        authenticateUser(cancelChecks: true)
    }
    
    private func applicationDidEnterBackground(notification: Notification) {
        if Seed.exists() {
            lockWindow.makeKeyAndVisible()
        }
        authenticationInProgress = false
        authorizationInProgress = false
        
        let lockView = UIView(frame: lockWindow.frame)
        let keynLogoView = UIImageView(image: UIImage(named: "logo"))
        
        keynLogoView.frame = CGRect(x: 0, y: 289, width: 375, height: 88)
        keynLogoView.contentMode = .scaleAspectFit
        lockView.addSubview(keynLogoView)
        lockView.backgroundColor = UIColor(rgb: 0x46319B)
        lockView.tag = lockViewTag
        
        lockWindow.addSubview(lockView)
        lockWindow.bringSubview(toFront: lockView)
        
        // TODO: Make autolayout constrained
        //            keynLogoView.heightAnchor.constraint(equalToConstant: 88).isActive = true
        //            keynLogoView.widthAnchor.constraint(equalTo: lockView.widthAnchor).isActive = true
        //            keynLogoView.centerXAnchor.constraint(equalTo: lockView.centerXAnchor).isActive = true
        //            keynLogoView.centerYAnchor.constraint(equalTo: lockView.centerYAnchor).isActive = true
    }
    
    private func didFinishLaunchingWithOptions(notification: Notification) {
        if Seed.exists() {
            lockWindow.makeKeyAndVisible()
        }
    }
    
    // MARK: LocalAuthentication
    
    func authenticateUser(cancelChecks: Bool) {
        if cancelChecks {
            guard !authenticationInProgress && !lockWindow.isHidden && !authorizationInProgress else {
                return
            }
            if let visibleViewController = UIApplication.shared.visibleViewController {
                guard !(visibleViewController is RequestViewController) && !(visibleViewController is RegistrationRequestViewController) else {
                    return
                }
            }
            
        }
        
        authenticationInProgress = true
        authenticateUser()
    }
    
    private func authenticateUser() {
        let localAuthenticationContext = LAContext()
        localAuthenticationContext.localizedFallbackTitle = "Use Passcode"
        
        var authError: NSError?
        let reasonString = "Unlock Keyn"
        
        guard localAuthenticationContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &authError) else {
            //TODO: Show appropriate alert if biometry/TouchID/FaceID is lockout or not enrolled
            authenticationInProgress = false
            print(self.evaluateAuthenticationPolicyMessageForLA(errorCode: authError!.code))
            return
        }
        
        localAuthenticationContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: reasonString)  { (succes, error) in
            DispatchQueue.main.async {
                if succes {
                    self.hideLockWindow()
                } else if let error = error {
                    print(self.evaluateAuthenticationPolicyMessageForLA(errorCode: error._code))
                    if error._code == LAError.userFallback.rawValue {
                        print("Handle fallback")
                    }
                }
            }
        }
    }
    
    func authorizeRequest(siteName: String, accountID: String?, type: BrowserMessageType, completion: @escaping (_: Bool, _: Error?)->()) {
        let authenticationContext = LAContext()
        var error: NSError?
        
        var localizedReason = ""
        switch type {
        case .add, .addAndChange:
            localizedReason = "Add \(siteName)"
        case .change:
            localizedReason = "Change password for \(siteName)"
        case .login:
            localizedReason = "Login to \(siteName)"
        case .reset:
            localizedReason = "Reset password for \(siteName)"
        case .register:
            localizedReason = "Register for \(siteName)"
        default:
            localizedReason = "\(siteName)"
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
    
    func launchRequestView(with notification: PushNotification) {
        // TODO: crash for now.
        authorizationInProgress = true
        do {
            if let session = try! Session.getSession(id: notification.sessionID) {
                let storyboard: UIStoryboard = UIStoryboard(name: "Request", bundle: nil)
                let viewController = storyboard.instantiateViewController(withIdentifier: "PasswordRequest") as! RequestViewController
                
                viewController.notification = notification
                viewController.session = session
                if lockWindow.isHidden {
                    UIApplication.shared.visibleViewController?.present(viewController, animated: true, completion: nil)
                } else {
                    lockWindow.rootViewController?.present(viewController, animated: true, completion: nil)
                }
            } else {
                authorizationInProgress = false
                print("Received request for session that doesn't exist.")
            }
        } catch {
            authorizationInProgress = false
            print("Session could not be decoded: \(error)")
        }
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
