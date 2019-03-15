/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import OneTimePassword
import LocalAuthentication

class AuthorizationGuard {

    static var authorizationInProgress = false

    let localAuthenticationContext = LAContext()
    let session: Session
    let type: KeynMessageType
    let browserTab: Int!    // Should be present for all requests
    let siteName: String!   // Should be present for all requests
    let siteURL: String!    // Should be present for all requests
    let accountId: String!  // Should be present for login, change and fill requests
    let siteId: String!     // Should be present for add site requests
    let password: String!   // Should be present for add site requests
    let username: String!   // Should be present for add site requests

    var authenticationReason: String {
        switch type {
        case .login:
            return "\("requests.login_to".localized.capitalized) \(siteName!)"
        case .add, .register:
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
    }

    // MARK: - Handle request responses

    func acceptRequest(completionHandler: @escaping () -> Void) throws {
        switch type {
        case .add, .register:
            try addSite(completionHandler: completionHandler)
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

    private func authorizeForKeychain(completionHandler: @escaping () -> Void) {
        defer {
            print("authorization ended")
            AuthorizationGuard.authorizationInProgress = false
        }
        LocalAuthenticationManager.shared.authorize(with: self.localAuthenticationContext) {
            do {
                guard let account = try Account.get(accountID: self.accountId, context: self.localAuthenticationContext, reason: self.authenticationReason) else {
                    Logger.shared.error("Account not found")
                    return // TODO: throw error
                }
                try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: self.localAuthenticationContext, reason: self.authenticationReason)
                completionHandler()
            } catch {
                Logger.shared.error("Error authorizing request", error: error)
            }
        }
    }

    private func addSite(completionHandler: @escaping () -> Void) throws {
        try PPD.get(id: siteId, completionHandler: { (ppd) in
            defer {
                AuthorizationGuard.authorizationInProgress = false
            }
            let site = Site(name: self.siteName ?? ppd?.name ?? "Unknown", id: self.siteId, url: self.siteURL ?? ppd?.url ?? "https://", ppd: ppd)
            do {
                let account = try Account(username: self.username, sites: [site], password: self.password, context: self.localAuthenticationContext)
                try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: self.localAuthenticationContext, reason: self.authenticationReason)
                NotificationCenter.default.post(name: .accountAdded, object: nil, userInfo: ["account": account])
                completionHandler()
            } catch {
                #warning("TODO: Show the user that the account could not be added.")
                Logger.shared.error("Account could not be saved.", error: error)
            }
        })
    }


    // MARK: - Static launch request view functions

    static func launchRequestView(with request: KeynRequest) {
        print("LaunchRequestViewCalled")
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
            #warning("TODO: Show the generic error viewController here with message that the request expired")
        } catch {
            AuthorizationGuard.authorizationInProgress = true
            Logger.shared.error("Could not decode session.", error: error)
        }
    }

    // MARK: - Static authorization functions

    static func addOTP(token: Token, account: Account, completionHandler: @escaping (_: Error?)->()) throws {
        authorizationInProgress = true
        authorizeWithoutKeychain(reason: account.hasOtp() ? "Add 2FA-code to \(account.site.name)" : "Update 2FA-code for \(account.site.name)") { (success, error) in
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

    static func authorizePairing(url: URL, completionHandler: @escaping (_: Session?, _: Error?) -> ()) throws {
        guard !authorizationInProgress else {
            Logger.shared.debug("authorizePairing() called while already in the process of authorizing.")
            return
        }
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

            authorizeWithoutKeychain(reason: "Pair with \(browser) on \(os).") { (success, error) in
                defer {
                    AuthorizationGuard.authorizationInProgress = false
                }
                if success {
                    do  {
                        let session = try Session.initiate(pairingQueueSeed: pairingQueueSeed, browserPubKey: browserPubKey, browser: browser, os: os)
                        completionHandler(session, nil)
                    } catch {
                        completionHandler(nil, error)
                    }
                } else if let error = error {
                    completionHandler(nil, error)
                }
            }
        } else {
            authorizationInProgress = false
            throw SessionError.invalid
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

}
