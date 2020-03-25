/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import OneTimePassword
import LocalAuthentication
import PromiseKit

enum AuthorizationError: KeynError {
    case accountOverflow
    case cannotAddAccount
    case noTeamSessionFound
    case notAdmin
    case inProgress
}

class AuthorizationGuard {

    static var authorizationInProgress = false

    var session: BrowserSession
    let type: KeynMessageType
    let accounts: [BulkAccount]!// Should be present for bulk add site requests
    private let accountIds: [Int: String]!// Should be present for bulk login requests
    private let browserTab: Int!        // Should be present for all requests
    private let siteName: String!       // Should be present for all requests
    private let siteURL: String!        // Should be present for all requests
    private let accountId: String!      // Should be present for login, change and fill requests
    private let siteId: String!         // Should be present for add site requests
    private let password: String!       // Should be present for add site requests
    private let username: String!       // Should be present for add site requests
    private let challenge: String!      // Should be present for webauthn requests
    private let rpId: String!           // Should be present for webauthn requests
    private let algorithms: [WebAuthnAlgorithm]! // Should be present for webauthn create requests

    private var authenticationReason: String {
        switch type {
        case .login, .addToExisting, .webauthnLogin:
            return String(format: "requests.login_to".localized, siteName!)
        case .bulkLogin:
            return String(format: "requests.login_to".localized, "\(accountIds.count) tabs")
        case .add, .register, .addAndLogin, .webauthnCreate:
            return String(format: "requests.add_site".localized, siteName!)
        case .change:
            return String(format: "requests.change_for".localized, siteName!)
        case .fill:
            return String(format: "requests.fill_for".localized, siteName!)
        case .adminLogin:
            return String(format: "requests.login_to".localized, "requests.keyn_for_teams".localized)
        default:
            return "requests.unknown_request".localized.capitalizedFirstLetter
        }
    }

    init?(request: KeynRequest, session: BrowserSession) {
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
        self.challenge = request.challenge
        self.rpId = request.relyingPartyId
        self.algorithms = request.algorithms
        self.accountIds = request.accountIDs
    }

    // MARK: - Handle request responses

    func acceptRequest() -> Promise<Account?> {
        var promise: Promise<Account?>
        switch type {
        case .add, .register, .addAndLogin:
            guard Properties.canAddAccount else {
                AuthorizationGuard.authorizationInProgress = false
                return Promise(error: AuthorizationError.cannotAddAccount)
            }
            promise = addSite().map { nil }
        case .addToExisting:
            promise = addToExistingAccount().map { nil }
        case .addBulk:
            guard Properties.canAddAccount else {
                AuthorizationGuard.authorizationInProgress = false
                return Promise(error: AuthorizationError.cannotAddAccount)
            }
            promise = addBulkSites().map { nil }
        case .login, .change, .fill:
            promise = authorize()
        case .bulkLogin:
            promise = authorizeBulkLogin().map { nil }
        case .adminLogin:
            promise = teamAdminLogin().map { nil }
        case .webauthnCreate:
            promise = webAuthnCreate().map { nil }
        case .webauthnLogin:
            promise = webAuthnLogin().map { nil }
        default:
            promise = .value(nil)
        }
        return promise.ensure {
            AuthorizationGuard.authorizationInProgress = false
        }

    }

    func rejectRequest() -> Guarantee<Void> {
        return firstly {
            session.cancelRequest(reason: .reject, browserTab: browserTab)
        }.asVoid().ensure {
            AuthorizationGuard.authorizationInProgress = false
        }.recover { error in
            Logger.shared.error("Reject message could not be sent.", error: error)
            return
        }
    }

    // MARK: - Private functions
    
    private func authorize() -> Promise<Account?> {
        var success = false
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false)
        }.map { context in
            guard let account: Account = try UserAccount.getAny(accountID: self.accountId, context: context) else {
                throw AccountError.notFound
            }
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            guard Properties.hasValidSubscription || account.enabled || !Properties.accountOverflow else {
                self.session.cancelRequest(reason: .disabled, browserTab: self.browserTab).catchLog("Error rejecting request")
                throw AuthorizationError.accountOverflow
            }
            try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: context!)
            success = true
            return account
        }.ensure {
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
    }

    private func authorizeBulkLogin() -> Promise<Void> {
        return firstly {
            LocalAuthenticationManager.shared   .authenticate(reason: self.authenticationReason, withMainContext: false)
        }.map { context in
            let accounts: [String: Account] = try UserAccount.allCombined(context: context)
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            let loginAccounts = try self.accountIds.mapValues { (accountId) -> BulkLoginAccount? in
                guard let account = accounts[accountId], let password = try account.password() else {
                    return nil
                }
                return BulkLoginAccount(username: account.username, password: password)
            }
            try self.session.sendBulkLoginResponse(browserTab: self.browserTab, accounts: loginAccounts, context: context)
        }
    }

    private func addToExistingAccount() -> Promise<Void> {
        var success = false
        return firstly {
            PPD.get(id: self.siteId)
        }.then { ppd in
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false).map { ($0, ppd) }
        }.map { context, ppd in
            let site = Site(name: self.siteName ?? ppd?.name ?? "Unknown", id: self.siteId, url: self.siteURL ?? ppd?.url ?? "https://", ppd: ppd)
            guard var account = try UserAccount.get(accountID: self.accountId, context: context) else {
                throw AccountError.notFound
            }
            try account.addSite(site: site)
            #warning("This seems off. Can this crash? Should LocalAuthenticationManager return the context non-optional")
            try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: context!)
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            success = true
        }.ensure {
            Logger.shared.analytics(.addSiteToExistingRequestAuthorized, properties: [.value: success])
        }
    }

    private func addSite() -> Promise<Void> {
        var success = false
        return firstly {
            PPD.get(id: siteId)
        }.then { ppd in
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false).map { ($0, ppd) }
        }.map { context, ppd in
            let site = Site(name: self.siteName ?? ppd?.name ?? "Unknown", id: self.siteId, url: self.siteURL ?? ppd?.url ?? "https://", ppd: ppd)
            let account = try UserAccount(username: self.username, sites: [site], password: self.password, rpId: nil, algorithms: nil, context: context)
            try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: context!)
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            success = true
        }.ensure {
            Logger.shared.analytics(.addSiteRequstAuthorized, properties: [.value: success])
        }
    }

    private func addBulkSites() -> Promise<Void> {
        #warning("TODO: Use plurals")
        var success = false
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: "\("requests.save".localized.capitalizedFirstLetter) \(accounts.count) \("request.accounts".localized)", withMainContext: false)
        }.then { (context) -> Promise<(LAContext?, [(BulkAccount, PPD?)])> in
            when(fulfilled: self.accounts.map { account in
                PPD.get(id: account.siteId).map { (account, $0) }
            }).map { (context, $0) }
        }.map { (context, accounts) in
            for (bulkAccount, ppd) in accounts {
                let site = Site(name: bulkAccount.siteName, id: bulkAccount.siteId, url: bulkAccount.siteURL, ppd: ppd)
                let _ = try UserAccount(username: bulkAccount.username, sites: [site], password: bulkAccount.password, rpId: nil, algorithms: nil, context: context)
            }
            try self.session.sendBulkAddResponse(browserTab: self.browserTab, context: context)
            success = true
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
        }.ensure {
            Logger.shared.analytics(.addBulkSitesRequestAuthorized, properties: [.value: success])
        }
    }

    private func teamAdminLogin() -> Promise<Void> {
        guard let teamSession = try? TeamSession.all().first else {
            AuthorizationGuard.showError(errorMessage: "errors.session_not_found".localized)
            return .value(())
        } // TODO: What if there's more than 1?
        guard teamSession.isAdmin else {
            AuthorizationGuard.showError(errorMessage: "errors.only_admins".localized)
            return .value(())
        }
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false)
        }.then { context in
            teamSession.getTeamSeed().map { ($0, context) }
        }.then { seed, context  in
            self.session.sendTeamSeed(pubkey: teamSession.signingPubKey, seed: seed.base64, browserTab: self.browserTab, context: context!)
        }.log("Error getting admin seed")
    }

    private func webAuthnCreate() -> Promise<Void> {
        var success = false
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false)
        }.map { context in
            let site = Site(name: self.siteName ?? "Unknown", id: self.siteId, url: self.siteURL ?? "https://", ppd: nil)
            let account = try UserAccount(username: self.username, sites: [site], password: nil, rpId: self.rpId, algorithms: self.algorithms, context: context)
            // TODO: Handle packed attestation format by called signWebAuthnAttestation and returning signature + counter
            try self.session.sendWebAuthnResponse(account: account, browserTab: self.browserTab, type: self.type, context: context!, signature: nil, counter: nil)
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            success = true
        }.ensure {
            Logger.shared.analytics(.webAuthnCreateRequestAuthorized, properties: [.value: success])
        }
    }

    private func webAuthnLogin() -> Promise<Void> {
        var success = false
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false)
        }.map { context in

            defer {
                Logger.shared.analytics(.webAuthnLoginRequestAuthorized, properties: [.value: success])
            }
            guard var account = try UserAccount.get(accountID: self.accountId, context: context) else {
                throw AccountError.notFound
            }
            let (signature, counter) = try account.webAuthnSign(challenge: self.challenge, rpId: self.rpId)
            try self.session.sendWebAuthnResponse(account: account, browserTab: self.browserTab, type: self.type, context: context!, signature: signature, counter: counter)
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            success = true
        }.ensure {

        }
    }


    // MARK: - Static launch request view functions

    static func launchRequestView(with request: KeynRequest) {
        guard !authorizationInProgress else {
            return
        }
        AuthorizationGuard.authorizationInProgress = true
        do {
            guard let sessionID = request.sessionID, let session = try BrowserSession.get(id: sessionID) else {
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

    // MARK: - Static authorization functionss

    static func addOTP(token: Token, account: UserAccount) throws -> Promise<Void> {
        authorizationInProgress = true
        let reason = account.hasOtp ? "\("accounts.add_2fa_code".localized) \(account.site.name)" : "\("accounts.update_2fa_code".localized) \(account.site.name)"
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: reason, withMainContext: false)
        }.asVoid().ensure {
            AuthorizationGuard.authorizationInProgress = false
        }
    }

    static func startAuthorization(reason: String, mainContext: Bool = false) -> Promise<LAContext?> {
        guard !authorizationInProgress else {
            return Promise(error: AuthorizationError.inProgress)
        }
        authorizationInProgress = true
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: reason, withMainContext: mainContext)
        }.ensure {
            authorizationInProgress = false
        }
    }

    static func authorizePairing(parameters: [String: String], context: LAContext?) -> Promise<Session> {
        do {
            guard let browserPubKey = parameters["p"], let pairingQueueSeed = parameters["q"], let browser = parameters["b"]?.capitalizedFirstLetter, let os = parameters["o"]?.capitalizedFirstLetter else {
                throw SessionError.invalid
            }
            guard try !BrowserSession.exists(id: browserPubKey.hash) else {
                throw SessionError.exists
            }
            var version: Int = 0
            if let versionString = parameters["v"], let versionNumber = Int(versionString) {
                version = versionNumber
            }
            if let type = parameters["t"], type == "1" {
                return TeamSession.initiate(pairingQueueSeed: pairingQueueSeed, browserPubKey: browserPubKey, role: browser, team: os, version: version)
            } else {
                guard let browser = Browser(rawValue: browser.lowercased()) else {
                    throw SessionError.unknownType
                }
                return BrowserSession.initiate(pairingQueueSeed: pairingQueueSeed, browserPubKey: browserPubKey, browser: browser, os: os, version: version)
            }
        } catch let error as KeychainError {
            Logger.shared.error("Keychain error retrieving session", error: error)
            return Promise(error: SessionError.invalid)
        } catch {
            return Promise(error: error)
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
