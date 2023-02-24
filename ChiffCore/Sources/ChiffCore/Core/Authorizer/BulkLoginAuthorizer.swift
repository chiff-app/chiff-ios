//
//  AddSiteAuthorizer.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

public class BulkLoginAuthorizer: Authorizer {
    public var session: BrowserSession
    public let type = ChiffMessageType.bulkLogin
    public let browserTab: Int
    public let code: String? = nil
    let count: Int
    let accountIds: [Int: String]
    public var logParam: String {
        return String(count)
    }

    public let requestText = "requests.confirm_login".localized.capitalizedFirstLetter
    public let successText = "requests.login_succesful".localized.capitalizedFirstLetter
    public var authenticationReason: String {
        return String(format: "requests.login_to".localized, "\(accountIds.count) tabs")
    }
    public let verify = true
    public var verifyText: String? {
        return String(format: "requests.verify_login".localized, "\(accountIds.count) tabs")
    }

    public required init(request: ChiffRequest, session: BrowserSession) throws {
        self.session = session
        guard let browserTab = request.browserTab,
              let accountIds = request.accountIDs else {
            throw AuthorizationError.missingData
        }
        self.browserTab = browserTab
        self.count = accountIds.count
        self.accountIds = accountIds
        Logger.shared.analytics(.bulkLoginRequestOpened)
    }

    public func authorize(verification: String?, startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        return firstly {
            self.authenticate(verification: verification)
        }.map { context in
            let accounts: [String: Account] = try UserAccount.allCombined(context: context)
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            let loginAccounts = try self.accountIds.mapValues { (accountId) -> BulkLoginAccount? in
                guard let account = accounts[accountId], let password = try account.password() else {
                    return nil
                }
                return BulkLoginAccount(username: account.username, password: password)
            }
            try self.session.sendBulkLoginResponse(browserTab: self.browserTab, accounts: loginAccounts, context: context)
            return nil
        }.ensure {
            self.writeLog(isRejected: false)
            Logger.shared.analytics(.bulkLoginRequestAuthorized)
        }
    }

}
