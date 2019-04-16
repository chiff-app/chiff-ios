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
            guard !authenticationInProgress &&
                !lockWindowIsHidden &&
                !LocalAuthenticationManager.shared.authenticationInProgress &&
                !AuthorizationGuard.authorizationInProgress else {
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
        let localizedReason = "requests.unlock_keyn".localized
        LocalAuthenticationManager.shared.authenticate(reason: localizedReason, withMainContext: true) { (context, error) in
            do {
                if let error = error {
                    throw error
                }
                let accounts = try Account.all(context: context)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .accountsLoaded, object: nil, userInfo: accounts)
                    self.hideLockWindow()
                }
            } catch {
                if let errorMessage = self.handleError(error: error) {
                    self.showError(errorMessage: errorMessage)
                }
                return
            }
        }
    }

    func handleError(error: Error) -> String? {
        switch error {
        case KeychainError.authenticationCancelled, LAError.systemCancel:
            Logger.shared.debug("Authentication was cancelled")
        case LAError.appCancel, LAError.invalidContext, LAError.notInteractive:
            Logger.shared.error("AuthenticateUser error", error: error)
            return "errors.local_authentication.generic".localized
        case LAError.passcodeNotSet:
            Logger.shared.error("AuthenticateUser error", error: error)
            return "errors.local_authentication.passcode_not_set".localized
        case let error as LAError:
            if #available(iOS 11.0, *) {
                switch error {
                case LAError.biometryNotAvailable:
                    return "errors.local_authentication.biometry_not_available".localized
                case LAError.biometryNotEnrolled:
                    return "errors.local_authentication.biometry_not_enrolled".localized
                default:
                    Logger.shared.debug("An LA error occured that was not catched. Check if it should be..", error: error)
                }
            } else {
                Logger.shared.debug("An LA error occured that was not catched. Check if it should be..", error: error)
            }
        default:
            Logger.shared.debug("An LA error occured that was not catched. Check if it should be..", error: error)
        }
        return nil
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

    private func showError(errorMessage: String) {
        DispatchQueue.main.async {
            UIApplication.shared.visibleViewController?.showError(message: errorMessage)
        }
    }

}
