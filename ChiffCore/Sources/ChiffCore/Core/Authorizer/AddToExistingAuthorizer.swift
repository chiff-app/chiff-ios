//
//  AddSiteAuthorizer.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

public class AddToExistingAuthorizer: Authorizer {
    public var session: BrowserSession
    public let type = ChiffMessageType.addToExisting
    public let browserTab: Int
    public let code: String? = nil
    let siteName: String
    let siteURL: String
    let siteId: String
    let accountId: String
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
              let siteURL = request.siteURL,
              let siteId = request.siteID,
              let accountId = request.accountID else {
            throw AuthorizationError.missingData
        }
        self.browserTab = browserTab
        self.siteName = siteName
        self.siteURL = siteURL
        self.siteId = siteId
        self.accountId = accountId
        Logger.shared.analytics(.addSiteToExistingRequestOpened)
    }

    public func authorize(verification: String?, startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        var success = false
        return firstly {
            try PPD.get(id: self.siteId, organisationKeyPair: TeamSession.organisationKeyPair())
        }.then { ppd in
            self.authenticate(verification: verification).map { ($0, ppd) }
        }.map { context, ppd in
            let site = Site(name: self.siteName, id: self.siteId, url: self.siteURL, ppd: ppd)
            guard var account = try UserAccount.get(id: self.accountId, context: context) else {
                throw AccountError.notFound
            }
            try account.addSite(site: site)
            try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: context, newPassword: nil)
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            success = true
            return nil
        }.ensure {
            self.writeLog(isRejected: false)
            Logger.shared.analytics(.addSiteToExistingRequestAuthorized, properties: [.value: success])
        }
    }

}
