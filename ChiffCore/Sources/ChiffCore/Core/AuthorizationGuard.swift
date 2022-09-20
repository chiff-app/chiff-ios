//
//  AuthorizationGuard.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import OneTimePassword
import LocalAuthentication
import PromiseKit

/// This class is responsible for launching the request UI when a request is received. Requests for which authorization is needed may originate from push messages,
/// but also from scanning QR-codes, e.g. pairing with the browser.
public class AuthorizationGuard {

    /// The `AuthorizationGuard` singleton.
    public static let shared = AuthorizationGuard()

    /// A variable to check the authorization of a request is currently in progress.
    public var authorizationInProgress = false

    /// Add a OTP (HOTP or TOTP) token to an account.
    /// - Parameters:
    ///   - token: The `Token` object, which an usally be created from an URL.
    ///   - account: The `UserAccount` to which the OTP should be added.
    /// - Returns: A Promise when the OTP-code is added
    public func addOTP(token: Token, account: UserAccount) -> Promise<Void> {
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
    public func pair(parameters: [String: String], reason: String, delegate: PairContainerDelegate) -> Promise<Session> {
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

}
