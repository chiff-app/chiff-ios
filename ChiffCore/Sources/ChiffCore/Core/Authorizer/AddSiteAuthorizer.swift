//
//  AddSiteAuthorizer.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

public class AddSiteAuthorizer: Authorizer {
    public var session: BrowserSession
    public let type: ChiffMessageType
    public let browserTab: Int
    let siteName: String
    let siteURL: String
    let siteId: String
    let username: String
    let password: String
    let notes: String?
    let askToChange: Bool?
    
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
        self.type = request.type
        guard let browserTab = request.browserTab,
              let siteName = request.siteName,
              let siteURL = request.siteURL,
              let siteId = request.siteID,
              let username = request.username,
              let password = request.password
              else {
            throw AuthorizationError.missingData
        }
        self.browserTab = browserTab
        self.siteName = siteName
        self.siteURL = siteURL
        self.siteId = siteId
        self.username = username
        self.password = password
        self.notes = request.notes
        self.askToChange = request.askToChange
        Logger.shared.analytics(.addSiteRequestOpened)
    }

    public func authorize(startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        var success = false
        return firstly {
            try PPD.get(id: siteId, organisationKeyPair: TeamSession.organisationKeyPair())
        }.then { ppd in
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false).map { ($0, ppd) }
        }.map { context, ppd in
            let site = Site(name: self.siteName, id: self.siteId, url: self.siteURL, ppd: ppd)
            let account = try UserAccount(username: self.username, sites: [site],
                                          password: self.password, webauthn: nil,
                                          notes: self.notes, askToChange: self.askToChange, context: context)
            try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: context, newPassword: nil)
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            success = true
            return nil
        }.ensure {
            self.writeLog(isRejected: false)
            Logger.shared.analytics(.addSiteRequestAuthorized, properties: [.value: success])
        }
    }

}
