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
        Account.all(reason: localizedReason, type: .ifNeeded) { (accounts, error) in
            do {
                if let error = error {
                    throw error
                }
                if !accounts!.isEmpty {
                    DispatchQueue.main.async { [weak self] in
                        NotificationCenter.default.post(name: .accountsLoaded, object: nil, userInfo: accounts!)
                        self?.hideLockWindow()
                    }
                } else {
                    LocalAuthenticationManager.shared.unlock(reason: localizedReason, completion: { (result, error) in
                        DispatchQueue.main.async { [weak self] in
                            if let error = error {
                                self?.handleError(error: error)
                                return
                            } else if result {
                                DispatchQueue.main.async { [weak self] in
                                    self?.hideLockWindow()
                                }
                            }
                        }
                    })
                }
            } catch {
                self.handleError(error: error)
            }
        }
    }

    private func handleError(error: Error) {
        switch error {
        case KeychainError.authenticationCancelled:
            Logger.shared.debug("Authentication was cancelled by an incoming request")
        case LAError.appCancel, LAError.invalidContext, LAError.notInteractive:
            showError(errorMessage: "errors.local_authentication.generic".localized)
        case LAError.passcodeNotSet:
            showError(errorMessage: "errors.local_authentication.passcode_not_set".localized)
        case let error as LAError:
            if #available(iOS 11.0, *) {
                switch error {
                case LAError.biometryNotAvailable:
                    showError(errorMessage: "errors.local_authentication.biometry_not_available".localized)
                case LAError.biometryNotEnrolled:
                    showError(errorMessage: "errors.local_authentication.biometry_not_enrolled".localized)
                default:
                    Logger.shared.debug("An LA error occured that was not catched. Check if it should be..", error: error)
                }
            } else {
                Logger.shared.debug("An LA error occured that was not catched. Check if it should be..", error: error)
            }
        default:
            showError(errorMessage: "\("errors.local_authentication.generic".localized): \(error)")
        }
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
