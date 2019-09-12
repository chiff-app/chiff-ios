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
    var pairingUrl: URL?

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

        if let url = pairingUrl, false {
            // Disabled for now, because opening from a QR-code may pose a security risk.
            pairingUrl = nil
            AuthorizationGuard.authorizePairing(url: url, mainContext: true, authenticationCompletionHandler: onAuthenticationResult) { (result) in
                DispatchQueue.main.async {
                    switch result {
                    case .success(let session): NotificationCenter.default.post(name: .sessionStarted, object: nil, userInfo: ["session": session])
                    case .failure(let error): Logger.shared.error("Error creating session.", error: error)
                    }
                }
            }
        } else {
            let localizedReason = "requests.unlock_keyn".localized
            LocalAuthenticationManager.shared.authenticate(reason: localizedReason, withMainContext: true, completionHandler: onAuthenticationResult(result:))
        }
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

    private func onAuthenticationResult(result: Result<LAContext?, Error>) {
        do {
            switch result {
            case .success(let context):
                let accounts = try Account.all(context: context, sync: true)
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .accountsLoaded, object: nil, userInfo: accounts)
                    self.hideLockWindow()
                }
            case .failure(let error): throw error
            }
        } catch let error as DecodingError {
            Logger.shared.error("Error decoding accounts", error: error)
            DispatchQueue.main.async {
                (self.lockWindow.rootViewController as? LoginViewController)?.showDecodingError(error: error)
            }
        } catch {
            if let errorMessage = LocalAuthenticationManager.shared.handleError(error: error) {
                Logger.shared.error(errorMessage, error: error)
                DispatchQueue.main.async {
                    (self.lockWindow.rootViewController as? LoginViewController)?.showError(message: errorMessage)
                }
            }
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
        lockView.translatesAutoresizingMaskIntoConstraints = false
        let keynLogoView = UIImageView(image: UIImage(named: "logo"))
        keynLogoView.translatesAutoresizingMaskIntoConstraints = false
        keynLogoView.tintColor = UIColor.white
        
        keynLogoView.frame = CGRect(x: 0, y: 0, width: 100, height: 88)
        keynLogoView.contentMode = .scaleAspectFit
        lockView.addSubview(keynLogoView)
        lockView.backgroundColor = UIColor.primary
        lockView.tag = lockViewTag
        
        lockWindow.addSubview(lockView)
        lockWindow.bringSubviewToFront(lockView)
        
        lockView.topAnchor.constraint(equalTo: lockWindow.topAnchor).isActive = true
        lockView.bottomAnchor.constraint(equalTo: lockWindow.bottomAnchor).isActive = true
        lockView.leadingAnchor.constraint(equalTo: lockWindow.leadingAnchor).isActive = true
        lockView.trailingAnchor.constraint(equalTo: lockWindow.trailingAnchor).isActive = true

        keynLogoView.heightAnchor.constraint(equalToConstant: 88).isActive = true
        keynLogoView.widthAnchor.constraint(equalTo: lockView.widthAnchor).isActive = true
        keynLogoView.centerXAnchor.constraint(equalTo: lockView.centerXAnchor).isActive = true
        keynLogoView.centerYAnchor.constraint(equalTo: lockView.centerYAnchor).isActive = true
    }
    
    private func didFinishLaunchingWithOptions(notification: Notification) {
        guard Seed.hasKeys else {
            return
        }
        lockWindow.makeKeyAndVisible()
        lockWindowIsHidden = false
    }

}
