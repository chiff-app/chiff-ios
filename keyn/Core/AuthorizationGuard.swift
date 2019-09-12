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
            return String(format: "requests.login_to".localized, siteName!)
        case .add, .register, .addAndLogin, .addToExisting:
            return String(format: "requests.add_site".localized, siteName!)
        case .change:
            return String(format: "requests.change_for".localized, siteName!)
        case .fill:
            return String(format: "requests.fill_for".localized, siteName!)
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

    func acceptRequest(completionHandler: @escaping (Result<Account?, Error>) -> Void) {
        
        func handleResult(_ error: Error?) {
            if let error = error {
                completionHandler(.failure(error))
            } else {
                completionHandler(.success(nil))
            }
        }
        
        switch type {
        case .add, .register, .addAndLogin:
            guard Properties.canAddAccount else {
                completionHandler(.failure(AuthorizationError.cannotAddAccount))
                return
            }
            addSite(completionHandler: handleResult)
        case .addToExisting:
            addToExistingAccount(completionHandler: handleResult)
        case .addBulk:
            guard Properties.canAddAccount else {
                completionHandler(.failure(AuthorizationError.cannotAddAccount))
                return
            }
            addBulkSites(completionHandler: handleResult)
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
        session.cancelRequest(reason: .reject, browserTab: browserTab) { (result) in
            switch result {
            case .failure(let error): Logger.shared.error("Reject message could not be sent.", error: error)
            case .success(_): break
            }
        }
        completionHandler()
    }

    // MARK: - Private functions
    
    private func authorize(completionHandler: @escaping (Result<Account?, Error>) -> Void) {
        LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false) { result in
            var success = false
            
            func onSuccess(context: LAContext?) throws {
                guard let account = try Account.get(accountID: self.accountId, context: context) else {
                    throw AccountError.notFound
                }
                NotificationCenter.default.post(name: .accountsLoaded, object: nil)
                guard Properties.hasValidSubscription || account.enabled || !Properties.accountOverflow else {
                    self.session.cancelRequest(reason: .reject, browserTab: self.browserTab, completionHandler: { (result) in // TODO: Change to .disabled after implemented in extension
                        switch result {
                        case .failure(let error): Logger.shared.error("Error rejecting request", error: error)
                        case .success(_): break
                        }
                    })
                    throw AuthorizationError.accountOverflow
                }
                try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: context!)
                success = true
                completionHandler(.success(account))
            }
            
            do {
                defer {
                    AuthorizationGuard.authorizationInProgress = false
                    switch self.type {
                    case .login:
                        Logger.shared.analytics(.loginRequestAuthorized, properties: [.value: success])
                    case .change:
                        Logger.shared.analytics(.changePasswordRequestAuthorized, properties: [.value: success])
                    case .fill:
                        Logger.shared.analytics(.fillPassworddRequestAuthorized, properties: [.value: success])
                    default:
                        Logger.shared.warning("Authorize called on the wrong type?")
                    }
                }
                try onSuccess(context: result.get())
            } catch {
                completionHandler(.failure(error))
            }
        }
    }

    private func addToExistingAccount(completionHandler: @escaping (Error?) -> Void) {
        PPD.get(id: siteId, completionHandler: { (ppd) in
            defer {
                AuthorizationGuard.authorizationInProgress = false
            }
            let site = Site(name: self.siteName ?? ppd?.name ?? "Unknown", id: self.siteId, url: self.siteURL ?? ppd?.url ?? "https://", ppd: ppd)
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false) { result in
                var success = false
                
                func onSuccess(context: LAContext?) throws {
                    var account = try Account.get(accountID: self.accountId, context: context)
                    guard account != nil  else {
                        throw AccountError.notFound
                    }
                    try account!.addSite(site: site)
                    try self.session.sendCredentials(account: account!, browserTab: self.browserTab, type: self.type, context: context!)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .accountsLoaded, object: nil)
                    }
                    success = true
                    completionHandler(nil)
                }
                
                do {
                    defer {
                        AuthorizationGuard.authorizationInProgress = false
                        Logger.shared.analytics(.addSiteToExistingRequestAuthorized, properties: [.value: success])
                    }
                    try onSuccess(context: result.get())
                } catch {
                    completionHandler(error)
                }
            }
        })

    }

    private func addSite(completionHandler: @escaping (Error?) -> Void) {
        PPD.get(id: siteId, completionHandler: { (ppd) in
            defer {
                AuthorizationGuard.authorizationInProgress = false
            }
            let site = Site(name: self.siteName ?? ppd?.name ?? "Unknown", id: self.siteId, url: self.siteURL ?? ppd?.url ?? "https://", ppd: ppd)
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false) { result in
                var success = false
                
                func onSuccess(context: LAContext?) throws {
                    let account = try Account(username: self.username, sites: [site], password: self.password, context: context)
                    try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: context!)
                    DispatchQueue.main.async {
                        NotificationCenter.default.post(name: .accountsLoaded, object: nil)
                    }
                    success = true
                    completionHandler(nil)
                }
                
                do {
                    defer {
                        Logger.shared.analytics(.addSiteRequstAuthorized, properties: [.value: success])
                    }
                    try onSuccess(context: result.get())
                } catch {
                    completionHandler(error)
                }
            }
        })
    }

    private func addBulkSites(completionHandler: @escaping (Error?) -> Void) {
        defer {
            AuthorizationGuard.authorizationInProgress = false
        }
        #warning("TODO: Use plurals")
        LocalAuthenticationManager.shared.authenticate(reason: "\("requests.save".localized.capitalizedFirstLetter) \(accounts.count) \("request.accounts".localized)", withMainContext: false) { (result) in
            var success = false
            
            func onSuccess(context: LAContext?) throws {
                #warning("TODO: Fetch PPD for each site")
                for bulkAccount in self.accounts {
                    let site = Site(name: bulkAccount.siteName, id: bulkAccount.siteId, url: bulkAccount.siteURL, ppd: nil)
                    let _ = try Account(username: bulkAccount.username, sites: [site], password: bulkAccount.password, context: context)
                }
                success = true
                DispatchQueue.main.async {
                    NotificationCenter.default.post(name: .accountsLoaded, object: nil)
                }
                completionHandler(nil)
            }
            do {
                defer {
                    Logger.shared.analytics(.addBulkSitesRequestAuthorized, properties: [.value: success])
                }
                try onSuccess(context: result.get())
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
            session.cancelRequest(reason: .expired, browserTab: browserTab) { (result) in
                switch result {
                case .failure(let error): Logger.shared.error("Error rejecting request", error: error)
                case .success(_): break
                }
            }
            showError(errorMessage: "requests.expired".localized)
        } catch {
            Logger.shared.error("Could not decode session.", error: error)
        }
    }

    // MARK: - Static authorization functionss

    static func addOTP(token: Token, account: Account, completionHandler: @escaping (Result<Void, Error>)->()) throws {
        authorizationInProgress = true
        let reason = account.hasOtp ? "\("accounts.add_2fa_code".localized) \(account.site.name)" : "\("accounts.update_2fa_code".localized) \(account.site.name)"
        LocalAuthenticationManager.shared.authenticate(reason: reason, withMainContext: false) { (result) in
            defer {
                AuthorizationGuard.authorizationInProgress = false
            }
            switch result {
            case .success(_): completionHandler(.success(()))
            case .failure(let error): completionHandler(.failure(error))
            }
        }
    }

    static func authorizePairing(url: URL, mainContext: Bool = false, authenticationCompletionHandler: ((Result<LAContext?, Error>) -> Void)?, completionHandler: @escaping (Result<Session, Error>) -> Void) {
        guard !authorizationInProgress else {
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
            LocalAuthenticationManager.shared.authenticate(reason: "\("requests.pair_with".localized) \(browser) \("requests.on".localized) \(os).", withMainContext: mainContext) { (result) in
                defer {
                    AuthorizationGuard.authorizationInProgress = false
                }
                switch result {
                case .success(_):
                    authenticationCompletionHandler?(result)
                    Session.initiate(pairingQueueSeed: pairingQueueSeed, browserPubKey: browserPubKey, browser: browser, os: os, completionHandler: completionHandler)
                case .failure(let error):
                    authenticationCompletionHandler?(result)
                    completionHandler(.failure(error))
                }
            }
        } catch let error as KeychainError {
            Logger.shared.error("Keychain error retrieving session", error: error)
            completionHandler(.failure(SessionError.invalid))
        } catch {
            completionHandler(.failure(error))
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
