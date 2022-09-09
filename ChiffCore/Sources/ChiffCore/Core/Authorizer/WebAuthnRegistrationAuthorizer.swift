//
//  AddSiteAuthorizer.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

public class WebAuthnRegistrationAuthorizer: Authorizer {
    public var session: BrowserSession
    public let type = ChiffMessageType.webauthnCreate
    public let browserTab: Int
    let siteName: String
    let siteURL: String
    let siteId: String
    let relyingPartyId: String
    let algorithms: [WebAuthnAlgorithm]
    let userHandle: String?
    let username: String
    let clientDataHash: String?
    let extensions: WebAuthnExtensions?
    let accountExists: Bool
    public var logParam: String {
        return siteName
    }

    public let requestText = "requests.add_account".localized.capitalizedFirstLetter
    public let successText = "requests.account_added".localized.capitalizedFirstLetter
    public var authenticationReason: String {
        return  String(format: "requests.add_site".localized, siteName)
    }

    public required init(request: ChiffRequest, session: BrowserSession) throws {
        self.session = session
        guard let browserTab = request.browserTab,
              let siteName = request.siteName,
              let siteURL = request.siteURL,
              let siteId = request.siteID,
              let username = request.username,
              let relyingPartyId = request.relyingPartyId,
              let algorithms = request.algorithms else {
            throw AuthorizationError.missingData
        }
        self.userHandle = request.userHandle
        self.accountExists = request.accountID != nil
        self.browserTab = browserTab
        self.siteName = siteName
        self.siteURL = siteURL
        self.siteId = siteId
        self.username = username
        self.relyingPartyId = relyingPartyId
        self.algorithms = algorithms
        self.clientDataHash = request.challenge
        self.extensions = request.webAuthnExtensions
        Logger.shared.analytics(.webAuthnCreateRequestOpened)
    }

    public func authorize(startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        var success = false
        guard !accountExists else {
            return Promise(error: ChiffErrorResponse.accountExists)
        }
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false)
        }.then { (context: LAContext) -> Promise<(UserAccount, WebAuthnAttestation?, LAContext)> in
            let site = Site(name: self.siteName, id: self.siteId, url: self.siteURL, ppd: nil)
            let webauthn = try WebAuthn(id: self.relyingPartyId, algorithms: self.algorithms, userHandle: self.userHandle)
            let account = try UserAccount(username: self.username,
                                          sites: [site],
                                          password: nil,
                                          webauthn: webauthn,
                                          notes: nil,
                                          askToChange: false,
                                          context: context)
            if let clientDataHash = self.clientDataHash {
                startLoading?("webauthn.attestation".localized)
                return account.webAuthn!.signAttestation(accountId: account.id, clientData: clientDataHash, extensions: self.extensions).map { (account, $0, context) }
            } else { // No attestation
                return .value((account, nil, context))
            }
        }.map { (account, attestation, context) in
            try self.session.sendWebAuthnResponse(account: account, browserTab: self.browserTab, type: self.type, context: context, signature: attestation?.signature, certificates: attestation?.certificates)
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            success = true
            return nil
        }.ensure {
            self.writeLog(isRejected: false)
            Logger.shared.analytics(.webAuthnCreateRequestAuthorized, properties: [.value: success])
        }
    }

}
