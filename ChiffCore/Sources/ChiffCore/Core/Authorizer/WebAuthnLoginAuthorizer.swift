//
//  AddSiteAuthorizer.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

public class WebAuthnLoginAuthorizer: Authorizer {
    public var session: BrowserSession
    public let type = ChiffMessageType.webauthnLogin
    public let browserTab: Int
    public let code: String?
    let siteName: String
    let relyingPartyId: String
    let accountId: String
    let challenge: String
    public var logParam: String {
        return siteName
    }

    public let requestText = "requests.confirm_login".localized.capitalizedFirstLetter
    public let successText = "requests.login_succesful".localized.capitalizedFirstLetter
    public var authenticationReason: String {
        return  String(format: "requests.login_to".localized, siteName)
    }
    public var verify: Bool {
        return code != nil
    }
    public var verifyText: String? {
        return String(format: "requests.verify_login".localized, siteName)
    }

    public required init(request: ChiffRequest, session: BrowserSession) throws {
        self.session = session
        guard let browserTab = request.browserTab,
              let siteName = request.siteName,
              let relyingPartyId = request.relyingPartyId,
              let challenge = request.challenge,
              let accountId = request.accountID else {
            throw AuthorizationError.missingData
        }
        self.code = request.verificationCode
        self.browserTab = browserTab
        self.siteName = siteName
        self.relyingPartyId = relyingPartyId
        self.accountId = accountId
        self.challenge = challenge
        Logger.shared.analytics(.webAuthnLoginRequestOpened)
    }

    public func authorize(verification: String?, startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        var success = false
        return firstly {
            self.authenticate(verification: verification)
        }.map { context in
            defer {
                Logger.shared.analytics(.webAuthnLoginRequestAuthorized, properties: [.value: success])
            }
            guard let account = try UserAccount.get(id: self.accountId, context: context) else {
                throw AccountError.notFound
            }
            let signature = try account.webAuthnSign(challenge: self.challenge, rpId: self.relyingPartyId)
            try self.session.sendWebAuthnResponse(account: account, browserTab: self.browserTab, type: self.type, context: context, signature: signature, certificates: nil)
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            success = true
            return nil
        }.ensure {
            self.writeLog(isRejected: false)
            Logger.shared.analytics(.loginRequestAuthorized, properties: [.value: success])
        }
    }

}
