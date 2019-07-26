/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import OneTimePassword
import LocalAuthentication

enum AuthorizationError: KeynError {
    case accountOverflow
    case cannotAddAccount
}

class AuthorizationGuard {

    static var authorizationInProgress = false

    let session: Session
    let type: KeynMessageType
    let accounts: [BulkAccount]!// Should be present for bulk add site requests
    private let browserTab: Int!        // Should be present for all requests
    private let siteName: String!       // Should be present for all requests
    private let siteURL: String!        // Should be present for all requests
    private let accountId: String!      // Should be present for login, change and fill requests
    private let siteId: String!         // Should be present for add site requests
    private let password: String!       // Should be present for add site requests
    private let username: String!       // Should be present for add site requests

    private var authenticationReason: String {
        switch type {
        case .login:
            return "\("requests.login_to".localized.capitalizedFirstLetter) \(siteName!)"
        case .add, .register, .addAndLogin, .addToExisting:
            return "\("requests.add_site".localized.capitalizedFirstLetter) \(siteName!)"
        case .change:
            return "\("requests.change_for".localized.capitalizedFirstLetter) \(siteName!)"
        case .fill:
            return "\("requests.fill_for".localized.capitalizedFirstLetter) \(siteName!)"
        default:
            return "requests.unknown_request".localized.capitalizedFirstLetter
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

    func acceptRequest(completionHandler: @escaping (_ account: Account?, _ error: Error?) -> Void) {
        switch type {
        case .add, .register, .addAndLogin:
            guard Properties.canAddAccount else {
                completionHandler(nil, AuthorizationError.cannotAddAccount)
                return
            }
            addSite() { error in
                completionHandler(nil, error)
            }
        case .addToExisting:
            addToExistingAccount() { error in
                completionHandler(nil, error)
            }
        case .addBulk:
            guard Properties.canAddAccount else {
                completionHandler(nil, AuthorizationError.cannotAddAccount)
                return
            }
            addBulkSites() { error in
                completionHandler(nil, error)
            }
        case .login, .change, .fill:
            authorize(completionHandler: completionHandler)
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

    private func authorize(completionHandler: @escaping (_ account: Account?, _ error: Error?) -> Void) {
        LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false) { (context, error) in
            do {
                defer {
                    AuthorizationGuard.authorizationInProgress = false
                }
                if let error = error {
                    throw error
                }
                guard let account = try Account.get(accountID: self.accountId, context: context) else {
                    throw AccountError.notFound
                }
                NotificationCenter.default.post(name: .accountsLoaded, object: nil)
                guard Properties.hasValidSubscription || account.enabled || !Properties.accountOverflow else {
                    self.session.cancelRequest(reason: .reject, browserTab: self.browserTab, completionHandler: { (_, error) in // TODO: Change to .disabled after implemented in extension
                        if let error = error {
                            Logger.shared.error("Error rejecting request", error: error)
                        }
                    })
                    throw AuthorizationError.accountOverflow
                }
                try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: context!)
                completionHandler(account, nil)
            } catch {
                completionHandler(nil, error)
            }
        }
    }

    private func addToExistingAccount(completionHandler: @escaping (_ error: Error?) -> Void) {
        PPD.get(id: siteId, completionHandler: { (ppd) in
            defer {
                AuthorizationGuard.authorizationInProgress = false
            }
            let site = Site(name: self.siteName ?? ppd?.name ?? "Unknown", id: self.siteId, url: self.siteURL ?? ppd?.url ?? "https://", ppd: ppd)
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false) { (context, error) in
                do {
                    defer {
                        AuthorizationGuard.authorizationInProgress = false
                    }
                    if let error = error {
                        throw error
                    }
                    var account = try Account.get(accountID: self.accountId, context: context)
                    guard account != nil  else {
                        throw AccountError.notFound
                    }
                    try account!.addSite(site: site)
                    try self.session.sendCredentials(account: account!, browserTab: self.browserTab, type: self.type, context: context!)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .accountsLoaded, object: nil)
                    }
                    completionHandler(nil)
                } catch {
                    completionHandler(error)
                }
            }
        })

    }

    private func addSite(completionHandler: @escaping (_ error: Error?) -> Void) {
        PPD.get(id: siteId, completionHandler: { (ppd) in
            defer {
                AuthorizationGuard.authorizationInProgress = false
            }
            let site = Site(name: self.siteName ?? ppd?.name ?? "Unknown", id: self.siteId, url: self.siteURL ?? ppd?.url ?? "https://", ppd: ppd)
            LocalAuthenticationManager.shared.authenticate(reason: "\("requests.save".localized.capitalizedFirstLetter) \(site.name)", withMainContext: false) { (context, error) in
                do {
                    if let error = error {
                        throw error
                    }
                    let account = try Account(username: self.username, sites: [site], password: self.password, context: context)
                    try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: context!)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .accountsLoaded, object: nil)
                    }
                    completionHandler(nil)
                } catch {
                    completionHandler(error)
                }
            }
        })
    }

    private func addBulkSites(completionHandler: @escaping (_ error: Error?) -> Void) {
        defer {
            AuthorizationGuard.authorizationInProgress = false
        }
        LocalAuthenticationManager.shared.authenticate(reason: "\("requests.save".localized.capitalizedFirstLetter) \(accounts.count) \("request.accounts".localized)", withMainContext: false) { (context, error) in
            do {
                if let error = error {
                    throw error
                }
                #warning("TODO: Fetch PPD for each site")
                for bulkAccount in self.accounts {
                    let site = Site(name: bulkAccount.siteName, id: bulkAccount.siteId, url: bulkAccount.siteURL, ppd: nil)
                    let _ = try Account(username: bulkAccount.username, sites: [site], password: bulkAccount.password, context: context)
                }
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .accountsLoaded, object: nil)
                }
                completionHandler(nil)
            } catch {
                completionHandler(error)
            }
        }
    }


    // MARK: - Static launch request view functions

    static func launchRequestView(with request: KeynRequest) {
        guard !authorizationInProgress else {
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

    // UNUSED. If we don't miss it, we can delete it.
    static func launchExpiredRequestView(with request: KeynRequest) {
        guard !authorizationInProgress else {
            return
        }
        defer {
            AuthorizationGuard.authorizationInProgress = false
        }
        AuthorizationGuard.authorizationInProgress = true
        do {
            guard let sessionID = request.sessionID, let session = try Session.get(id: sessionID), let browserTab = request.browserTab else {
                throw SessionError.doesntExist
            }
            session.cancelRequest(reason: .expired, browserTab: browserTab) { (_, error) in
                if let error = error {
                    Logger.shared.error("Error rejecting request", error: error)
                }
            }
            showError(errorMessage: "requests.expired".localized)
        } catch {
            Logger.shared.error("Could not decode session.", error: error)
        }
    }

    // MARK: - Static authorization functionss

    static func addOTP(token: Token, account: Account, completionHandler: @escaping (_: Error?)->()) throws {
        authorizationInProgress = true
        let reason = account.hasOtp() ? "\("accounts.add_2fa_code".localized) \(account.site.name)" : "\("accounts.update_2fa_code".localized) \(account.site.name)"
        LocalAuthenticationManager.shared.authenticate(reason: reason, withMainContext: false) { (context, error) in
            defer {
                AuthorizationGuard.authorizationInProgress = false
            }
            if context != nil {
                completionHandler(nil)
            } else if let error = error {
                completionHandler(error)
            }
        }
    }

    static func authorizePairing(url: URL, authenticationCompletionHandler: (() -> Void)?, completionHandler: @escaping (_: Session?, _: Error?) -> Void) {
        guard !authorizationInProgress else {
            Logger.shared.debug("authorizePairing() called while already in the process of authorizing.")
            return
        }
        defer {
            authorizationInProgress = false
        }
        authorizationInProgress = true
        do {
            guard let parameters = url.queryParameters, let browserPubKey = parameters["p"], let pairingQueueSeed = parameters["q"], let browser = parameters["b"]?.capitalizedFirstLetter, let os = parameters["o"]?.capitalizedFirstLetter else {
                throw SessionError.invalid
            }
            guard Properties.browsers.contains(browser), Properties.systems.contains(os) else {
                throw SessionError.unknownType
            }
            guard try !Session.exists(id: browserPubKey.hash) else {
                throw SessionError.exists
            }
            LocalAuthenticationManager.shared.authenticate(reason: "\("requests.pair_with".localized) \(browser) \("requests.on".localized) \(os).", withMainContext: false) { (context, error) in
                defer {
                    AuthorizationGuard.authorizationInProgress = false
                }
                if context != nil {
                    authenticationCompletionHandler?()
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
