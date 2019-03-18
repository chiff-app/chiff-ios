/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication
import OneTimePassword

class AuthenticationGuard {

    static let shared = AuthenticationGuard()
    private let lockWindow: UIWindow
    private let lockViewTag = 390847239047
    private var lockWindowIsHidden = true {
        didSet {
            lockWindow.isHidden = lockWindowIsHidden
        }
    }

    var localAuthenticationContext = LAContext()
    var authenticationInProgress = false

    private init() {
        lockWindow = UIWindow(frame: UIScreen.main.bounds)
        lockWindow.windowLevel = UIWindow.Level.alert
        lockWindow.screen = UIScreen.main
        lockWindow.rootViewController = UIStoryboard.main.instantiateViewController(withIdentifier: "LoginController") as! LoginViewController

        let nc = NotificationCenter.default
        nc.addObserver(forName: UIApplication.didEnterBackgroundNotification, object: nil, queue: OperationQueue.main, using: applicationDidEnterBackground)
        nc.addObserver(forName: UIApplication.didFinishLaunchingNotification, object: nil, queue: OperationQueue.main, using: didFinishLaunchingWithOptions)
        nc.addObserver(forName: UIApplication.willEnterForegroundNotification, object: nil, queue: OperationQueue.main, using: applicationWillEnterForeground)
        nc.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: OperationQueue.main, using: applicationDidBecomeActive)
    }

    // MARK: - LocalAuthentication


    func authenticateUser(cancelChecks: Bool) {
        if cancelChecks {
            guard !authenticationInProgress && !lockWindowIsHidden else {
                return
            }

            if let visibleViewController = UIApplication.shared.visibleViewController {
                guard !(visibleViewController is RequestViewController) else {
                    return
                }
            }
        }
        authenticationInProgress = true
        authenticateUser()
    }

    func hideLockWindow() {
        UIView.animate(withDuration: 0.25, animations: {
            self.lockWindow.alpha = 0.0
        }) { if $0 {
            self.lockWindowIsHidden = true
            self.lockWindow.alpha = 1.0
            self.authenticationInProgress = false
            }
        }
    }

//    func hasFaceID() -> Bool {
//        if #available(iOS 11.0, *) {
//            let context = LAContext.init()
//            var error: NSError?
//            if context.canEvaluatePolicy(LAPolicy.deviceOwnerAuthenticationWithBiometrics, error: &error) {
//                return context.biometryType == LABiometryType.faceID
//            }
//        }
//
//        return false
//    }

    // MARK: - Private functions
    
    private func authenticateUser() {
        let unlocalizedReason = "Unlock Keyn"
        Account.all(reason: unlocalizedReason, type: .ifNeeded) { (accounts, error) in
            if let error = error {
                #warning("TODO: Handle fallback for lack of biometric authentication")
                Logger.shared.error("Error getting accounts.", error: error)
                return
            }
            guard let accounts = accounts else {
                return
            }
            if !accounts.isEmpty {
                DispatchQueue.main.async { [weak self] in
                    NotificationCenter.default.post(name: .accountsLoaded, object: nil, userInfo: accounts)
                    self?.hideLockWindow()
                }
            } else {
                LocalAuthenticationManager.shared.unlock(reason: unlocalizedReason, completion: { (result, error) in
                    DispatchQueue.main.async { [weak self] in
                        if let error = error {
                            print("TODO: handle authentication error")
                            return
                        }
                        if result {
                            DispatchQueue.main.async { [weak self] in
                                self?.hideLockWindow()
                            }
                        } else {
                            print("TODO: handle authentication unsuccesful")
                        }
                    }
                })
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
    
    // MARK: - UIApplication Notification Handlers
    
    private func applicationWillEnterForeground(notification: Notification) {
        if let lockView = lockWindow.viewWithTag(lockViewTag) {
            lockView.removeFromSuperview()
        }
    }
    
    private func applicationDidBecomeActive(notification: Notification) {
        if let lockView = lockWindow.viewWithTag(lockViewTag) {
            lockView.removeFromSuperview()
        }
        self.authenticateUser(cancelChecks: true)
    }
    
    private func applicationDidEnterBackground(notification: Notification) {
        guard Seed.hasKeys else {
            return
        }
        lockWindow.makeKeyAndVisible()
        lockWindowIsHidden = false
        authenticationInProgress = false
        LocalAuthenticationManager.shared.mainContext.invalidate()
        
        let lockView = UIView(frame: lockWindow.frame)
        let keynLogoView = UIImageView(image: UIImage(named: "logo"))
        
        keynLogoView.frame = CGRect(x: 0, y: 289, width: 375, height: 88)
        keynLogoView.contentMode = .scaleAspectFit
        lockView.addSubview(keynLogoView)
        lockView.backgroundColor = UIColor(rgb: 0x46319B)
        lockView.tag = lockViewTag
        
        lockWindow.addSubview(lockView)
        lockWindow.bringSubviewToFront(lockView)
        
        #warning("TODO:Make autolayout constrained")
        //            keynLogoView.heightAnchor.constraint(equalToConstant: 88).isActive = true
        //            keynLogoView.widthAnchor.constraint(equalTo: lockView.widthAnchor).isActive = true
        //            keynLogoView.centerXAnchor.constraint(equalTo: lockView.centerXAnchor).isActive = true
        //            keynLogoView.centerYAnchor.constraint(equalTo: lockView.centerYAnchor).isActive = true
    }
    
    private func didFinishLaunchingWithOptions(notification: Notification) {
        guard Seed.hasKeys else {
            return
        }
        lockWindow.makeKeyAndVisible()
        lockWindowIsHidden = false
    }

}
