/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import OneTimePassword
import LocalAuthentication

class AuthorizationGuard {

    static var authorizationInProgress = false

    let session: Session
    let type: KeynMessageType
    let browserTab: Int!        // Should be present for all requests
    let siteName: String!       // Should be present for all requests
    let siteURL: String!        // Should be present for all requests
    let accountId: String!      // Should be present for login, change and fill requests
    let siteId: String!         // Should be present for add site requests
    let password: String!       // Should be present for add site requests
    let username: String!       // Should be present for add site requests
    let accounts: [BulkAccount]!// Should be present for bulk add site requests

    var authenticationReason: String {
        switch type {
        case .login:
            return "\("requests.login_to".localized.capitalized) \(siteName!)"
        case .add, .register, .addAndLogin:
            return "\("requests.add_site".localized.capitalized) \(siteName!)"
        case .change:
            return "\("requests.change_for".localized.capitalized) \(siteName!)"
        case .fill:
            return "\("requests.fill_for".localized.capitalized) \(siteName!)"
        default:
            return "Unknown request type"
        }
    }

    init?(request: KeynRequest, session: Session) {
        guard request.verifyIntegrity() else {
            return nil
        }
        self.type = request.type
        self.session = session
        self.browserTab = request.browserTab
        self.siteId = request.siteID
        self.siteName = request.siteName
        self.siteURL = request.siteURL
        self.password = request.password
        self.username = request.username
        self.accountId = request.accountID
        self.accounts = request.accounts
    }

    // MARK: - Handle request responses

    func acceptRequest(completionHandler: @escaping (_ error: Error?) -> Void) {
        switch type {
        case .add, .register, .addAndLogin:
            addSite(completionHandler: completionHandler)
        case .addBulk:
            addBulkSites(completionHandler: completionHandler)
        case .login, .change, .fill:
            authorizeForKeychain(completionHandler: completionHandler)
        default:
            AuthorizationGuard.authorizationInProgress = false
            return
        }

    }

    func rejectRequest(completionHandler: @escaping () -> Void) {
        defer {
            AuthorizationGuard.authorizationInProgress = false
        }
        session.cancelRequest(reason: .reject, browserTab: browserTab) { (_, error) in
            if let error = error {
                Logger.shared.error("Reject message could not be sent.", error: error)
            }
        }
        completionHandler()
    }

    // MARK: - Private functions

    private func authorizeForKeychain(completionHandler: @escaping (_ error: Error?) -> Void) {
        Account.get(accountID: self.accountId, reason: self.authenticationReason, type: .override) { (account, context, error) in
            do {
                defer {
                    AuthorizationGuard.authorizationInProgress = false
                }
                if let error = error {
                    throw error
                }
                try self.session.sendCredentials(account: account!, browserTab: self.browserTab, type: self.type, context: context!)
                completionHandler(nil)
            } catch {
                Logger.shared.error("Error authorizing request", error: error)
                completionHandler(error)
            }
        }
    }

    private func addSite(completionHandler: @escaping (_ error: Error?) -> Void) {
        PPD.get(id: siteId, completionHandler: { (ppd) in
            defer {
                AuthorizationGuard.authorizationInProgress = false
            }
            let site = Site(name: self.siteName ?? ppd?.name ?? "Unknown", id: self.siteId, url: self.siteURL ?? ppd?.url ?? "https://", ppd: ppd)
            do {
                let _ = try Account(username: self.username, sites: [site], password: self.password, type: .override) { (account, context, error) in
                    do {
                        if let error = error {
                            throw error
                        }
                        try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: context!)
                        NotificationCenter.default.post(name: .accountAdded, object: nil, userInfo: ["account": account])
                        completionHandler(nil)
                    } catch {
                        Logger.shared.error("Add account response could not be sent", error: error)
                        completionHandler(error)
                    }
                }
            } catch {
                Logger.shared.error("Account could not be saved.", error: error)
                completionHandler(error)
            }
        })
    }

    private func addBulkSites(completionHandler: @escaping (_ error: Error?) -> Void) {
        defer {
            AuthorizationGuard.authorizationInProgress = false
        }
        LocalAuthenticationManager.shared.evaluatePolicy(reason: "Add \(accounts.count) accounts") { (context, error) in
            for account in self.accounts {
                let site = Site(name: account.siteName, id: account.siteId, url: account.siteURL, ppd: nil)
                do {
                    let _ = try Account(username: account.username, sites: [site], password: account.password, type: .ifNeeded, context: context) { (account, context, error) in
                        do {
                            if let error = error {
                                throw error
                            }
                            NotificationCenter.default.post(name: .accountAdded, object: nil, userInfo: ["account": account])
                        } catch {
                            Logger.shared.error("Add account response could not be sent", error: error)
                        }
                    }
                } catch {
                    Logger.shared.error("Account could not be saved.", error: error)
                }
            }
            completionHandler(nil)
        }
    }


    // MARK: - Static launch request view functions

    static func launchRequestView(with request: KeynRequest) {
        guard !authorizationInProgress else {
            Logger.shared.debug("AuthorizationGuard.launchRequestView() called while already in the process of authorizing.")
            return
        }
        AuthorizationGuard.authorizationInProgress = true
        do {
            guard let sessionID = request.sessionID, let session = try Session.get(id: sessionID) else {
                AuthorizationGuard.authorizationInProgress = false
                throw SessionError.doesntExist
            }
            let storyboard: UIStoryboard = UIStoryboard.get(.request)
            let viewController = storyboard.instantiateViewController(withIdentifier: "PasswordRequest") as! RequestViewController
            guard let authorizationGuard = AuthorizationGuard(request: request, session: session) else {
                AuthorizationGuard.authorizationInProgress = false
                return
            }
            viewController.authorizationGuard = authorizationGuard
            UIApplication.shared.visibleViewController?.present(viewController, animated: true, completion: nil)
        } catch {
            AuthorizationGuard.authorizationInProgress = false
            Logger.shared.error("Could not decode session.", error: error)
        }
    }

    static func launchExpiredRequestView(with request: KeynRequest) {
        guard !authorizationInProgress else {
            return
        }
        AuthorizationGuard.authorizationInProgress = true
        do {
            guard let sessionID = request.sessionID, let session = try Session.get(id: sessionID), let browserTab = request.browserTab else {
                AuthorizationGuard.authorizationInProgress = true
                throw SessionError.doesntExist
            }
            session.cancelRequest(reason: .expired, browserTab: browserTab) { (_, error) in
                AuthorizationGuard.authorizationInProgress = true
                if let error = error {
                    Logger.shared.error("Error rejecting request", error: error)
                }
            }
            showError(errorMessage: "requests.expired".localized)
        } catch {
            AuthorizationGuard.authorizationInProgress = true
            Logger.shared.error("Could not decode session.", error: error)
        }
    }

    // MARK: - Static authorization functionss

    static func addOTP(token: Token, account: Account, completionHandler: @escaping (_: Error?)->()) throws {
        authorizationInProgress = true
        authorizeWithoutKeychain(reason: account.hasOtp() ? "\("accounts.add_2fa_code".localized) \(account.site.name)" : "\("accounts.update_2fa_code".localized) \(account.site.name)") { (success, error) in
            defer {
                AuthorizationGuard.authorizationInProgress = false
            }
            if success {
                completionHandler(nil)
            } else if let error = error {
                completionHandler(error)
            }
        }
    }

    static func authorizePairing(url: URL, completionHandler: @escaping (_: Session?, _: Error?) -> ()) {
        guard !authorizationInProgress else {
            Logger.shared.debug("authorizePairing() called while already in the process of authorizing.")
            return
        }
        defer {
            authorizationInProgress = false
        }
        authorizationInProgress = true
        do {
            guard let parameters = url.queryParameters, let browserPubKey = parameters["p"], let pairingQueueSeed = parameters["q"], let browser = parameters["b"], let os = parameters["o"] else {
                throw SessionError.invalid
            }
            guard try !Session.exists(id: browserPubKey.hash) else {
                throw SessionError.exists
            }
            authorizeWithoutKeychain(reason: "Pair with \(browser) on \(os).") { (success, error) in
                defer {
                    AuthorizationGuard.authorizationInProgress = false
                }
                if success {
                    Session.initiate(pairingQueueSeed: pairingQueueSeed, browserPubKey: browserPubKey, browser: browser, os: os, completion: completionHandler)
                } else if let error = error {
                    completionHandler(nil, error)
                }
            }
        } catch let error as KeychainError {
            Logger.shared.error("Keychain error retrieving session", error: error)
            completionHandler(nil, SessionError.invalid)
        } catch {
            completionHandler(nil, error)
        }
    }

    private static func authorizeWithoutKeychain(reason: String, completion: @escaping (_: Bool, _: Error?) -> ()) {
        var error: NSError?
        let context = LAContext()
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            #warning("TODO: Handle fingerprint absence in authorize function")
            Logger.shared.error("TODO: Handle fingerprint absence.", error: error)
            completion(false, error)
            return
        }

        context.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: reason,
            reply: completion
        )
    }

    private static func showError(errorMessage: String) {
        DispatchQueue.main.async {
            guard let viewController = UIStoryboard.main.instantiateViewController(withIdentifier: "ErrorViewController") as? ErrorViewController else {
                Logger.shared.error("Can't create ErrorViewController so we have no way to start the app.")
                return
            }

            viewController.errorMessage = errorMessage
            UIApplication.shared.visibleViewController?.present(viewController, animated: true, completion: nil)
        }
    }

}
