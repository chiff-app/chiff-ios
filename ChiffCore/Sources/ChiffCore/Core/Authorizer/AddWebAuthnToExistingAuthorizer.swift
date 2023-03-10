//
//  AddWebAuthnToExistingAuthorizer.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

public class AddWebAuthnToExistingAuthorizer: Authorizer {
    public var session: BrowserSession
    public let type = ChiffMessageType.addWebauthnToExisting
    public let browserTab: Int
    public let code: String?
    let siteName: String
    let siteURL: String
    let siteId: String
    let relyingPartyId: String
    let algorithms: [WebAuthnAlgorithm]
    let userHandle: String?
    let accountId: String
    let clientDataHash: String?
    let extensions: WebAuthnExtensions?
    public var logParam: String {
        return siteName
    }

    public let requestText = "requests.update_account".localized.capitalizedFirstLetter
    public let successText = "requests.account_updated".localized.capitalizedFirstLetter
    public var authenticationReason: String {
        return  String(format: "requests.update_this".localized, siteName)
    }
    public var verify: Bool {
        return Properties.extraVerification
    }
    public var verifyText: String? {
        return String(format: "requests.verify_update_account".localized, siteName)
    }

    public required init(request: ChiffRequest, session: BrowserSession) throws {
        self.session = session
        guard let browserTab = request.browserTab,
              let siteName = request.siteName,
              let siteURL = request.siteURL,
              let siteId = request.siteID,
              let accountId = request.accountID,
              let relyingPartyId = request.relyingPartyId,
              let algorithms = request.algorithms else {
            throw AuthorizationError.missingData
        }
        self.code = request.verificationCode
        self.accountId = accountId
        self.browserTab = browserTab
        self.siteName = siteName
        self.siteURL = siteURL
        self.siteId = siteId
        self.relyingPartyId = relyingPartyId
        self.algorithms = algorithms
        self.userHandle = request.userHandle
        self.clientDataHash = request.challenge
        self.extensions = request.webAuthnExtensions
        Logger.shared.analytics(.webAuthnCreateRequestOpened)
    }

    public func authorize(verification: String?, startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        var success = false
        return firstly {
            self.authenticate(verification: verification)
        }.then { (context: LAContext) -> Promise<(UserAccount, WebAuthnAttestation?, LAContext)> in
            guard var account = try UserAccount.get(id: self.accountId, context: context) else {
                throw AccountError.notFound
            }
            try account.addWebAuthn(rpId: self.relyingPartyId, algorithms: self.algorithms, userHandle: self.userHandle, context: context)
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
