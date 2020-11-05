//
//  AddSiteAuthorizer.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

class WebAuthnRegistrationAuthorizer: Authorizer {
    var session: BrowserSession
    let type = KeynMessageType.webauthnCreate
    let browserTab: Int
    let siteName: String
    let siteURL: String
    let siteId: String
    let relyingPartyId: String
    let algorithms: [WebAuthnAlgorithm]
    let username: String

    let requestText = "requests.add_account".localized.capitalizedFirstLetter
    let successText = "requests.account_added".localized.capitalizedFirstLetter
    var authenticationReason: String {
        return  String(format: "requests.add_site".localized, siteName)
    }

    required init(request: KeynRequest, session: BrowserSession) throws {
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
        self.browserTab = browserTab
        self.siteName = siteName
        self.siteURL = siteURL
        self.siteId = siteId
        self.username = username
        self.relyingPartyId = relyingPartyId
        self.algorithms = algorithms
        Logger.shared.analytics(.webAuthnCreateRequestOpened)
    }

    func authorize(startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        var success = false
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false)
        }.map { context in
            let site = Site(name: self.siteName, id: self.siteId, url: self.siteURL, ppd: nil)
            let account = try UserAccount(username: self.username,
                                          sites: [site],
                                          password: nil,
                                          rpId: self.relyingPartyId,
                                          algorithms: self.algorithms,
                                          notes: nil,
                                          askToChange: false,
                                          context: context)
            try self.session.sendWebAuthnResponse(account: account, browserTab: self.browserTab, type: self.type, context: context, signature: nil, counter: nil)
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            success = true
            return nil
        }.ensure {
            Logger.shared.analytics(.webAuthnCreateRequestAuthorized, properties: [.value: success])
        }
    }

}
