//
//  AddSiteAuthorizer.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

public class ChangeAuthorizer: Authorizer {
    public var session: BrowserSession
    public let type = ChiffMessageType.change
    public let browserTab: Int
    let siteName: String
    let siteURL: String
    let siteId: String
    let accountId: String
    public var logParam: String {
        return siteName
    }

    public let requestText = "requests.change_password".localized.capitalizedFirstLetter
    public let successText = "requests.new_password_generated".localized.capitalizedFirstLetter
    public var authenticationReason: String {
        return String(format: "requests.change_for".localized, siteName)
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
        Logger.shared.analytics(.changePasswordRequestOpened)
    }

    public func authorize(startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        var success = false
        return firstly {
            when(fulfilled: LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false),
                 try PPD.get(id: self.siteId, organisationKeyPair: TeamSession.organisationKeyPair()))
        }.map { (context, ppd) in
            guard var account: UserAccount = try UserAccount.get(id: self.accountId, context: context) else {
                if try SharedAccount.get(id: self.accountId, context: context) != nil {
                    throw AuthorizationError.cannotChangeAccount
                } else {
                    throw AccountError.notFound
                }
            }
            account.sites[0].ppd = ppd
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: context, newPassword: account.nextPassword(context: context))
            success = true
            NotificationCenter.default.postMain(name: .passwordChangeConfirmation, object: self.session, userInfo: ["context": context as Any])
            return account
        }.ensure {
            self.writeLog(isRejected: false)
            Logger.shared.analytics(.changePasswordRequestAuthorized, properties: [.value: success])
        }
    }

}
