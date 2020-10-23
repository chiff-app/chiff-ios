//
//  AddSiteAuthorizer.swift
//  keyn
//
//  Created by Bas Doorn on 22/10/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import LocalAuthentication
import PromiseKit

class BulkLoginAuthorizer: Authorizer {
    var session: BrowserSession
    let type = KeynMessageType.bulkLogin
    let browserTab: Int
    let count: Int
    let accountIds: [Int: String]

    let requestText = "requests.confirm_login".localized.capitalizedFirstLetter
    let successText = "requests.login_succesful".localized.capitalizedFirstLetter
    var authenticationReason: String {
        return String(format: "requests.login_to".localized, "\(accountIds.count) tabs")
    }

    required init(request: KeynRequest, session: BrowserSession) throws {
        self.session = session
        guard let browserTab = request.browserTab,
              let count = request.count,
              let accountIds = request.accountIDs else {
            throw AuthorizationError.missingData
        }
        self.browserTab = browserTab
        self.count = count
        self.accountIds = accountIds
        Logger.shared.analytics(.bulkLoginRequestOpened)
    }

    func authorize(startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false)
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
            Logger.shared.analytics(.bulkLoginRequestAuthorized)
        }
    }

}