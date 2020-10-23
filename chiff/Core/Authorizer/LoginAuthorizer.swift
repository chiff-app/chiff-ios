//
//  AddSiteAuthorizer.swift
//  keyn
//
//  Created by Bas Doorn on 22/10/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import LocalAuthentication
import PromiseKit

class LoginAuthorizer: Authorizer {
    var session: BrowserSession
    let type: KeynMessageType
    let browserTab: Int
    let siteName: String
    let accountId: String
    let siteURL: String?
    let siteId: String?

    var successText: String {
        switch type {
        case .fill, .getDetails:
            return "requests.get_password_successful".localized.capitalizedFirstLetter
        default:
            return "requests.login_succesful".localized.capitalizedFirstLetter
        }
    }
    var requestText: String {
        switch type {
        case .fill, .getDetails:
            return "requests.get_password".localized.capitalizedFirstLetter
        default:
            return "requests.confirm_login".localized.capitalizedFirstLetter
        }
    }
    var authenticationReason: String {
        switch type {
        case .fill, .getDetails:
            return String(format: "requests.get_for".localized, siteName)
        default:
            return String(format: "requests.login_to".localized, siteName)
        }
    }

    required init(request: KeynRequest, session: BrowserSession) throws {
        self.session = session
        self.type = request.type
        guard let browserTab = request.browserTab,
              let siteName = request.siteName,
              let accountId = request.accountID else {
            throw AuthorizationError.missingData
        }
        self.browserTab = browserTab
        self.siteName = siteName
        self.siteURL = request.siteURL
        self.siteId = request.siteID
        self.accountId = accountId
        switch type {
        case .fill:
            Logger.shared.analytics(.fillPasswordRequestOpened)
        case .getDetails:
            Logger.shared.analytics(.getDetailsRequestOpened)
        default:
            Logger.shared.analytics(.loginRequestOpened)
        }
    }

    func authorize(startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        var success = false
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false)
        }.map { context in
            guard let account: Account = try UserAccount.getAny(id: self.accountId, context: context) else {
                throw AccountError.notFound
            }
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: context!, newPassword: nil)
            success = true
            return account
        }.ensure {
            AuthorizationGuard.shared.authorizationInProgress = false
            switch self.type {
            case .login:
                Logger.shared.analytics(.loginRequestAuthorized, properties: [.value: success])
            case .fill:
                Logger.shared.analytics(.fillPasswordRequestAuthorized, properties: [.value: success])
            case .getDetails:
                Logger.shared.analytics(.getDetailsRequestAuthorized, properties: [.value: success])
            default:
                Logger.shared.warning("Authorize called on the wrong type?")
            }
        }
    }

}
