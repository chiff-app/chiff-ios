//
//  AuthorizationGuard.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import OneTimePassword
import LocalAuthentication
import PromiseKit

/// This class is responsible for launching the request UI when a request is received. Requests for which authorization is needed may originate from push messages,
/// but also from scanning QR-codes, e.g. pairing with the browser.
class AuthorizationGuard {

    /// The `AuthorizationGuard` singleton.
    static let shared = AuthorizationGuard()

    /// A variable to check the authorization of a request is currently in progress.
    var authorizationInProgress = false

    /// Launch a the RequestViewController with the appropriate `Authorizer`.
    /// - Parameter request: The `ChiffRequest` that has been received.
    func launchRequestView(with request: ChiffRequest) {
        guard !authorizationInProgress else {
            return
        }
        authorizationInProgress = true
        do {
            guard let sessionID = request.sessionID, let session = try BrowserSession.get(id: sessionID, context: nil) else {
                authorizationInProgress = false
                throw SessionError.doesntExist
            }
            let storyboard: UIStoryboard = UIStoryboard.get(.request)
            guard let viewController = storyboard.instantiateViewController(withIdentifier: "PasswordRequest") as? RequestViewController else {
                throw TypeError.wrongViewControllerType
            }
            viewController.authorizer = try createAuthorizer(request: request, session: session)
            UIApplication.shared.visibleViewController?.present(viewController, animated: true, completion: nil)
        } catch {
            authorizationInProgress = false
            Logger.shared.error("Could not decode session.", error: error)
        }
    }

    /// Add a OTP (HOTP or TOTP) token to an account.
    /// - Parameters:
    ///   - token: The `Token` object, which an usally be created from an URL.
    ///   - account: The `UserAccount` to which the OTP should be added.
    /// - Returns: A Promise when the OTP-code is added
    func addOTP(token: Token, account: UserAccount) -> Promise<Void> {
        authorizationInProgress = true
        var account = account
        let reason = account.hasOtp ? "\("accounts.add_2fa_code".localized) \(account.site.name)" : "\("accounts.update_2fa_code".localized) \(account.site.name)"
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: reason, withMainContext: false)
        }.map { _ in
            try account.setOtp(token: token)
        }.asVoid().ensure {
            self.authorizationInProgress = false
        }
    }

    /// Pair with another device. This can be a BrowserSession or a TeamSession, depending on the parameters.
    /// - Parameters:
    ///   - parameters: The URL-parameters of the URL that was scanned.
    ///   - reason: The authentication reason that is presented to the user.
    ///   - delegate: The delegate to update the UI.
    /// - Returns: The Promise of a Session.
    func pair(parameters: [String: String], reason: String, delegate: PairContainerDelegate) -> Promise<Session> {
        guard !authorizationInProgress else {
            return Promise(error: AuthorizationError.inProgress)
        }
        authorizationInProgress = true
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: reason, withMainContext: false)
        }.then { _ -> Promise<Session> in
            delegate.startLoading()
            Logger.shared.analytics(.qrCodeScanned, properties: [.value: true])
            guard let browserPubKey = parameters["p"],
                  let pairingQueueSeed = parameters["q"],
                  let browser = parameters["b"]?.capitalizedFirstLetter,
                  let os = parameters["o"]?.capitalizedFirstLetter else {
                throw SessionError.invalid
            }
            guard let hash = browserPubKey.hash, !BrowserSession.exists(id: hash) else {
                throw SessionError.exists
            }
            var version: Int = 0
            if let versionString = parameters["v"], let versionNumber = Int(versionString) {
                version = versionNumber
            }
            if let type = parameters["t"], type == "1" {
                guard let organisationKey = parameters["k"], let teamId = parameters["i"] else {
                    throw SessionError.invalid
                }
                return TeamSession.initiate(pairingQueueSeed: pairingQueueSeed,
                                            teamId: teamId,
                                            browserPubKey: browserPubKey,
                                            role: browser,
                                            team: os,
                                            version: version,
                                            organisationKey: organisationKey)
            } else {
                guard let browser = Browser(rawValue: browser.lowercased()) else {
                    throw SessionError.unknownType
                }
                return BrowserSession.initiate(pairingQueueSeed: pairingQueueSeed, browserPubKey: browserPubKey, browser: browser, os: os, version: version)
            }
        }.recover { error -> Promise<Session> in
            throw error is KeychainError ? SessionError.invalid : error
        }.ensure {
            self.authorizationInProgress = false
        }
    }

    /// Create a new Team. This can be used to create a Team / Organization by scanning a QR-code.
    /// - Parameters:
    ///   - parameters: The URL-parameters of the URL that was scanned.
    ///   - reason: The authentication reason that is presented to the user.
    ///   - delegate: The delegate to update the UI.
    /// - Returns: The Promise of a Session.
    func createTeam(parameters: [String: String], reason: String, delegate: PairContainerDelegate) -> Promise<Session> {
        guard !authorizationInProgress else {
            return Promise(error: AuthorizationError.inProgress)
        }
        authorizationInProgress = true
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: reason, withMainContext: false)
        }.then { _ -> Promise<Session> in
            delegate.startLoading()
            Logger.shared.analytics(.qrCodeScanned, properties: [.value: true])
            guard let orderKey = parameters["k"], let name = parameters["n"] else {
                throw SessionError.invalid
            }
            let team = try Team(name: name)
            return team.create(orderKey: orderKey)
        }.ensure {
            self.authorizationInProgress = false
        }
    }

    /// Redirect the user to a ViewController that shows an error message. This is used only for errors that put the app in a state that cannot be fixed.
    /// - Parameter errorMessage: The error message that should be displayed.
    func showError(errorMessage: String) {
        DispatchQueue.main.async {
            guard let viewController = UIStoryboard.main.instantiateViewController(withIdentifier: "ErrorViewController") as? ErrorViewController else {
                Logger.shared.error("Can't create ErrorViewController so we have no way to start the app.")
                return
            }

            viewController.errorMessage = errorMessage
            UIApplication.shared.visibleViewController?.present(viewController, animated: true, completion: nil)
        }
    }

    // MARK: - Private functions

    private func createAuthorizer(request: ChiffRequest, session: BrowserSession) throws -> Authorizer {
        switch request.type {
        case .add, .register, .addAndLogin:
            return try AddSiteAuthorizer(request: request, session: session)
        case .addToExisting:
            return try AddToExistingAuthorizer(request: request, session: session)
        case .addBulk:
            return try AddBulkSiteAuthorizer(request: request, session: session)
        case .change:
            return try ChangeAuthorizer(request: request, session: session)
        case .login, .fill, .getDetails:
            return try LoginAuthorizer(request: request, session: session)
        case .bulkLogin:
            return try BulkLoginAuthorizer(request: request, session: session)
        case .adminLogin:
            return try TeamAdminLoginAuthorizer(request: request, session: session)
        case .webauthnCreate:
            return try WebAuthnRegistrationAuthorizer(request: request, session: session)
        case .webauthnLogin:
            return try WebAuthnLoginAuthorizer(request: request, session: session)
        case .updateAccount:
            return try UpdateAccountAuthorizer(request: request, session: session)
        case .createOrganisation:
            return try CreateOrganisationAuthorizer(request: request, session: session)
        default:
            throw AuthorizationError.unknownType
        }
    }

}
