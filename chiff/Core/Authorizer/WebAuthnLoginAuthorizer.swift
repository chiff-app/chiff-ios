//
//  AddSiteAuthorizer.swift
//  keyn
//
//  Created by Bas Doorn on 22/10/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import LocalAuthentication
import PromiseKit

class WebAuthnLoginAuthorizer: Authorizer {
    var session: BrowserSession
    let type = KeynMessageType.webauthnLogin
    let browserTab: Int
    let siteName: String
    let relyingPartyId: String
    let accountId: String
    let challenge: String

    let requestText = "requests.confirm_login".localized.capitalizedFirstLetter
    let successText = "requests.login_succesful".localized.capitalizedFirstLetter
    var authenticationReason: String {
        return  String(format: "requests.login_to".localized, siteName)
    }

    required init(request: KeynRequest, session: BrowserSession) throws {
        self.session = session
        guard let browserTab = request.browserTab,
              let siteName = request.siteName,
              let relyingPartyId = request.relyingPartyId,
              let challenge = request.challenge,
              let accountId = request.accountID else {
            throw AuthorizationError.missingData
        }
        self.browserTab = browserTab
        self.siteName = siteName
        self.relyingPartyId = relyingPartyId
        self.accountId = accountId
        self.challenge = challenge
        Logger.shared.analytics(.webAuthnLoginRequestOpened)
    }

    func authorize(startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        var success = false
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false)
        }.map { context in
            defer {
                Logger.shared.analytics(.webAuthnLoginRequestAuthorized, properties: [.value: success])
            }
            guard var account = try UserAccount.get(id: self.accountId, context: context) else {
                throw AccountError.notFound
            }
            let (signature, counter) = try account.webAuthnSign(challenge: self.challenge, rpId: self.relyingPartyId)
            try self.session.sendWebAuthnResponse(account: account, browserTab: self.browserTab, type: self.type, context: context, signature: signature, counter: counter)
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            success = true
            return nil
        }.ensure {
            Logger.shared.analytics(.loginRequestAuthorized, properties: [.value: success])
        }
    }

}
