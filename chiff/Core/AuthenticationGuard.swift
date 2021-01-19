//
//  AuthenticationGuard.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import LocalAuthentication
import OneTimePassword
import PromiseKit

/// This class is responsible for authenticating the user when opening the app and hiding and showing the lock screen.
class AuthenticationGuard {

    /// The `AuthenticationGuard` singleton instance.
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
        if let loginController =  UIStoryboard.main.instantiateViewController(withIdentifier: "LoginController") as? LoginViewController {
            lockWindow.rootViewController = loginController
        }

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(applicationDidEnterBackground(notification:)), name: UIApplication.didEnterBackgroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(didFinishLaunchingWithOptions(notification:)), name: UIApplication.didFinishLaunchingNotification, object: nil)
        nc.addObserver(self, selector: #selector(applicationWillEnterForeground(notification:)), name: UIApplication.willEnterForegroundNotification, object: nil)
        nc.addObserver(self, selector: #selector(applicationDidBecomeActive(notification:)), name: UIApplication.didBecomeActiveNotification, object: nil)

    }

    // MARK: - LocalAuthentication

    /// Authenticate the user to unlock the app.
    /// - Parameter cancelChecks: Set this parameter to `true` if authenticating should only happen if an authentication operation is not already in progress.
    ///     If it is, Promise will be cancelled.
    func authenticateUser(cancelChecks: Bool) {
        firstly {
            after(seconds: 0.5)
        }.then(on: .main) { (_) -> Promise<LAContext> in
            if cancelChecks {
                guard !self.authenticationInProgress &&
                    !self.lockWindowIsHidden &&
                    !LocalAuthenticationManager.shared.authenticationInProgress &&
                        !AuthorizationGuard.shared.authorizationInProgress else {
                    throw PMKError.cancelled
                }

                if let visibleViewController = UIApplication.shared.visibleViewController {
                    guard !(visibleViewController is RequestViewController) else {
                         throw PMKError.cancelled
                    }
                }
            }
            self.authenticationInProgress = true
            return LocalAuthenticationManager.shared.authenticate(reason: "requests.unlock_keyn".localized, withMainContext: true)
        }.map(on: .main ) { (context) -> LAContext in
            NotificationCenter.default.post(name: .authenticated, object: self, userInfo: nil)
            return context
        }.map { (context) -> ([String: Account], LAContext) in
            Keychain.shared.migrate(context: context)
            let accounts = try UserAccount.allCombined(context: context, migrateVersion: true)
            if #available(iOS 12.0, *), Properties.reloadAccounts {
                UserAccount.reloadIdentityStore()
                Properties.reloadAccounts = false
            }
            return (accounts, context)
        }.map(on: .main) { (accounts, context) -> LAContext in
            NotificationCenter.default.post(name: .accountsLoaded, object: self, userInfo: accounts)
            self.hideLockWindow()
            return context
        }.then { (context) -> Promise<Void> in
            return when(fulfilled: TeamSession.updateAllTeamSessions(), UserAccount.sync(context: context), TeamSession.sync(context: context), self.updateNews())
        }.catch(on: .main) { error in
            if case SyncError.dataDeleted = error {
                self.showDataDeleted()
            } else if let error = error as? DecodingError {
                Logger.shared.error("Error decoding accounts", error: error)
                (self.lockWindow.rootViewController as? LoginViewController)?.showDecodingError(error: error)
            } else if let errorMessage = LocalAuthenticationManager.shared.handleError(error: error) {
                Logger.shared.error(errorMessage, error: error)
                (self.lockWindow.rootViewController as? LoginViewController)?.showAlert(message: errorMessage)
            }
        }

    }

    /// Hide the lock window, effectively putting the app in the *unlocked* state. Only makes sense if the user is really authenticated, otherwise the data from the Keychain is not loaded.
    /// - Parameter delay: Optionally, a delay in milliseconds can be provided to make the UX more smooth.
    func hideLockWindow(delay: Double? = nil) {
        guard LocalAuthenticationManager.shared.isAuthenticated else {
            return
        }
        let duration = 0.25
        let animations = {
            self.lockWindow.alpha = 0.0
        }
        func completion(_ result: Bool) {
            if result {
                self.lockWindowIsHidden = true
                self.lockWindow.alpha = 1.0
                self.authenticationInProgress = false
                self.lockWindow.rootViewController?.dismiss(animated: false, completion: nil)
            }
        }
        if let delay = delay {
            UIView.animate(withDuration: duration, delay: delay, animations: animations, completion: completion)
        } else {
            UIView.animate(withDuration: duration, animations: animations, completion: completion)
        }
    }

    // MARK: - Private functions

    private func showDataDeleted() {
        UIView.animate(withDuration: 0.25, animations: {
            self.lockWindow.alpha = 1.0
        }, completion: { result in
            if result {
                self.lockWindow.makeKeyAndVisible()
                self.lockWindowIsHidden = false
                (self.lockWindow.rootViewController as? LoginViewController)?.showDataDeleted()
            }
        })
    }

    private func updateNews() -> Promise<Void> {
        return firstly {
            API.shared.request(path: "news", method: .get, parameters: ["t": "\(Properties.firstLaunchTimestamp)"])
        }.map { messages in
            let localization = Locale.current.languageCode ?? "en"
            guard let (id, news) = messages.first(where: { !Properties.receivedNewsMessage(id: $0.key) }),
                let object = news as? [String: [String: String]],
                let title = object["title"]?[localization],
                let message = object["message"]?[localization] else {
                return
            }
            UIApplication.shared.visibleViewController?.showAlert(message: message, title: title, handler: { (_) in
                Properties.addReceivedNewsMessage(id: id)
            })
        }
    }

    // MARK: - UIApplication Notification Handlers

    @objc private func applicationWillEnterForeground(notification: Notification) {
        if let lockView = lockWindow.viewWithTag(lockViewTag) {
            lockView.removeFromSuperview()
        }
    }

    @objc private func applicationDidBecomeActive(notification: Notification) {
        if let lockView = lockWindow.viewWithTag(lockViewTag) {
            lockView.removeFromSuperview()
        }
        self.authenticateUser(cancelChecks: true)
    }

    @objc private func applicationDidEnterBackground(notification: Notification) {
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

    @objc private func didFinishLaunchingWithOptions(notification: Notification) {
        guard Seed.hasKeys else {
            return
        }
        lockWindow.makeKeyAndVisible()
        lockWindowIsHidden = false
    }

}
