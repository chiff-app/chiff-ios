/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import LocalAuthentication
import OneTimePassword
import PromiseKit

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
        firstly {
            LocalAuthenticationManager.shared.authenticate(reason: "requests.unlock_keyn".localized, withMainContext: true)
        }.map(on: .main) { (context) -> LAContext? in
            let accounts = try UserAccount.allCombined(context: context, sync: true)
            if #available(iOS 12.0, *), Properties.reloadAccounts {
                UserAccount.reloadIdentityStore()
                Properties.reloadAccounts = false
            }
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil, userInfo: accounts)
            self.hideLockWindow()
            return context
        }.then { (context) -> Promise<Void> in
            when(fulfilled: TeamSession.updateAllTeamSessions(pushed: false, logo: true), UserAccount.sync(context: context), TeamSession.sync(context: context))
        }.catch { error in
            if case SyncError.dataDeleted = error {
                (self.lockWindow.rootViewController as? LoginViewController)?.showDataDeleted()
            } else if let error = error as? DecodingError {
                Logger.shared.error("Error decoding accounts", error: error)
                (self.lockWindow.rootViewController as? LoginViewController)?.showDecodingError(error: error)
            } else if let errorMessage = LocalAuthenticationManager.shared.handleError(error: error) {
                Logger.shared.error(errorMessage, error: error)
                (self.lockWindow.rootViewController as? LoginViewController)?.showAlert(message: errorMessage)
            }
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
