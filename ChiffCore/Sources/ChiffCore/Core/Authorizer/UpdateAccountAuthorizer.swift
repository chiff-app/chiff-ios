//
//  AddSiteAuthorizer.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

public class UpdateAccountAuthorizer: Authorizer {
    public var session: BrowserSession
    public let type = ChiffMessageType.updateAccount
    public let browserTab: Int
    public let code: String?
    let siteName: String
    let siteURL: String
    let accountId: String
    let username: String?
    let password: String?
    let newSiteName: String?
    let notes: String?
    public var logParam: String {
        return siteName
    }

    public let requestText = "requests.update_account".localized.capitalizedFirstLetter
    public let successText = "requests.account_updated".localized.capitalizedFirstLetter
    public var authenticationReason: String {
        return  String(format: "requests.update_this".localized, siteName)
    }
    public var verify: Bool {
        return code != nil
    }
    public var verifyText: String? {
        return String(format: "requests.verify_update_account".localized, siteName)
    }

    public required init(request: ChiffRequest, session: BrowserSession) throws {
        self.session = session
        guard let browserTab = request.browserTab,
              let siteName = request.siteName,
              let siteURL = request.siteURL,
              let accountId = request.accountID else {
            throw AuthorizationError.missingData
        }
        self.code = request.verificationCode
        self.browserTab = browserTab
        self.siteName = siteName
        self.siteURL = siteURL
        self.accountId = accountId
        self.username = request.username
        self.password = request.password
        self.newSiteName = request.newSiteName
        self.notes = request.notes
        Logger.shared.analytics(.updateAccountRequestOpened)
    }

    public func authorize(verification: String?, startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        var success = false
        return firstly {
            self.authenticate(verification: verification)
        }.map { context in
            guard var account: UserAccount = try UserAccount.get(id: self.accountId, context: context) else {
                if try SharedAccount.get(id: self.accountId, context: context) != nil {
                    throw AuthorizationError.cannotChangeAccount
                } else {
                    throw AccountError.notFound
                }
            }
            try account.update(username: self.username, password: self.password, siteName: self.newSiteName, url: self.siteURL, askToLogin: nil, askToChange: nil)
            if let notes = self.notes {
                try account.updateNotes(notes: notes)
            }
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: context, newPassword: nil)
            success = true
            return account
        }.ensure {
            self.writeLog(isRejected: false)
            Logger.shared.analytics(.updateAccountRequestAuthorized, properties: [.value: success])
        }
    }

}
