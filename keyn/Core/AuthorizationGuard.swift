//
//  AuthorizationGuard.swift
//  keyn
//
//  Created by Bas Doorn on 18/02/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import Foundation
import OneTimePassword
import LocalAuthentication

class AuthorizationGuard {
    
    static let shared = AuthorizationGuard()
    
    var authorizationInProgress = false
    
    private init() {}
    
    func addOTP(token: Token, account: Account, completion: @escaping (_: Error?)->()) throws {
        authorizationInProgress = true
        authorize(reason: account.hasOtp() ? "Add 2FA-code to \(account.site.name)" : "Update 2FA-code for \(account.site.name)") { [weak self] (success, error) in
            if success {
                self?.authorizationInProgress = false
                completion(nil)
            } else if let error = error {
                self?.authorizationInProgress = false
                completion(error)
            }
        }
    }
    
    func authorizePairing(url: URL, unlock: Bool = false, completion: @escaping (_: Session?, _: Error?)->()) throws {
        authorizationInProgress = true
        if let parameters = url.queryParameters, let browserPubKey = parameters["p"], let pairingQueueSeed = parameters["q"], let browser = parameters["b"], let os = parameters["o"] {
            do {
                guard try !Session.exists(id: browserPubKey.hash) else {
                    authorizationInProgress = false
                    throw SessionError.exists
                }
            } catch {
                authorizationInProgress = false
                throw SessionError.invalid
            }
            authorize(reason: "Pair with \(browser) on \(os).") { [weak self] (success, error) in
                if success {
                    do  {
                        let session = try Session.initiate(pairingQueueSeed: pairingQueueSeed, browserPubKey: browserPubKey, browser: browser, os: os)
                        self?.authorizationInProgress = false
                        completion(session, nil)
                    } catch {
                        self?.authorizationInProgress = false
                        completion(nil, error)
                    }
//                    self?.unlock() // Why is here?
                } else if let error = error {
                    self?.authorizationInProgress = false
                    completion(nil, error)
                }
            }
        } else {
            authorizationInProgress = false
            throw SessionError.invalid
        }
    }
    
    func authorizeRequest(siteName: String, accountID: String?, type: KeynMessageType, completion: @escaping (_: Bool, _: Error?)->()) {
        let localizedReason = requestText(siteName: siteName, type: type) ?? "\(siteName)"
        authorize(reason: localizedReason, completion: completion)
    }
    
    func requestText(siteName: String, type: KeynMessageType, accountExists: Bool = true) -> String? {
        switch type {
        case .login:
            return "\("requests.login_to".localized.capitalized) \(siteName)?"
        case .fill:
            return "\("requests.fill_for".localized.capitalized) \(siteName)?"
        case .change:
            return accountExists ? "\("requests.change_for".localized.capitalized) \(siteName)?" : "\("requests.add_site".localized.capitalized) \(siteName)?"
        case .add:
            return "\("requests.add_site".localized.capitalized) \(siteName)?"
        default:
            return nil
        }
        
    }
    
    func launchRequestView(with notification: PushNotification) {
        authorizationInProgress = true
        do {
            if let session = try Session.get(id: notification.sessionID) {
                // TODO: Refactor not notifications
                let storyboard: UIStoryboard = UIStoryboard.get(.request)
                let viewController = storyboard.instantiateViewController(withIdentifier: "PasswordRequest") as! RequestViewController
                viewController.type = notification.type
                viewController.notification = notification
                viewController.session = session
                UIApplication.shared.visibleViewController?.present(viewController, animated: true, completion: nil)
            } else {
                authorizationInProgress = false
                Logger.shared.warning("Received request for session that doesn't exist.")
            }
        } catch {
            authorizationInProgress = false
            Logger.shared.error("Could not decode session.", error: error)
        }
    }
    
    // MARK: - Private functions
    
    private func authorize(reason: String, completion: @escaping (_: Bool, _: Error?)->()) {
        let authenticationContext = LAContext()
        var error: NSError?
        
        guard authenticationContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            Logger.shared.error("TODO: Handle fingerprint absence.", error: error)
            return
        }
        
        authenticationContext.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason,
            reply: completion
        )
    }
}

