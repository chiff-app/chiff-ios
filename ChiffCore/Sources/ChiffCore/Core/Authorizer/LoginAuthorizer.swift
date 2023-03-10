//
//  AddSiteAuthorizer.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

public class LoginAuthorizer: Authorizer {
    public var session: BrowserSession
    public let type: ChiffMessageType
    public let browserTab: Int
    public let code: String?
    public let siteName: String
    let accountId: String
    let siteURL: String?
    let siteId: String?
    
    public var logParam: String {
        return siteName
    }
    private var context: LAContext?

    public var successText: String {
        switch type {
        case .fill, .getDetails:
            return "requests.get_password_successful".localized.capitalizedFirstLetter
        default:
            return "requests.login_succesful".localized.capitalizedFirstLetter
        }
    }
    public var requestText: String {
        switch type {
        case .fill, .getDetails:
            return "requests.get_password".localized.capitalizedFirstLetter
        default:
            return "requests.confirm_login".localized.capitalizedFirstLetter
        }
    }
    public var authenticationReason: String {
        switch type {
        case .fill, .getDetails:
            return String(format: "requests.get_for".localized, siteName)
        default:
            return String(format: "requests.login_to".localized, siteName)
        }
    }
    public var verify: Bool {
        return Properties.extraVerification
    }
    public var verifyText: String? {
        return String(format: "requests.verify_login".localized, siteName)
    }

    public required init(request: ChiffRequest, session: BrowserSession) throws {
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
        self.code = request.verificationCode
        switch type {
        case .fill:
            Logger.shared.analytics(.fillPasswordRequestOpened)
        case .getDetails:
            Logger.shared.analytics(.getDetailsRequestOpened)
        default:
            Logger.shared.analytics(.loginRequestOpened)
        }
    }
    
    public func authorize(verification: String?, startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        var success = false
        return firstly {
            self.authenticate(verification: verification)
        }.map { context in
            guard let account: Account = try UserAccount.getAny(id: self.accountId, context: context) else {
                throw AccountError.notFound
            }
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            try self.session.sendCredentials(account: account, browserTab: self.browserTab, type: self.type, context: context, newPassword: nil)
            success = true
            return account
        }.ensure {
            self.writeLog(isRejected: false)
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
