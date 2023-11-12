//
//  AddSiteAuthorizer.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

public class ExportAuthorizer: Authorizer {
    public var session: BrowserSession
    public let type = ChiffMessageType.export
    public let browserTab: Int
    public let code: String?
    public var logParam: String {
        return "TODO"
    }

    public let requestText = "requests.confirm_login".localized.capitalizedFirstLetter
    public let successText = "requests.login_succesful".localized.capitalizedFirstLetter
    public var authenticationReason: String {
        return "TODO"
    }
    public let verify = true
    public var verifyText: String? {
        return "TODO"
    }

    public required init(request: ChiffRequest, session: BrowserSession) throws {
        self.session = session
        guard let browserTab = request.browserTab,
              let code = request.verificationCode else {
            throw AuthorizationError.missingData
        }
        self.code = code
        self.browserTab = browserTab
//        Logger.shared.analytics(.bulkLoginRequestOpened)
    }

    public func authorize(verification: String?, startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        return firstly {
            return self.authenticate(verification: verification)
        }.map { (context: LAContext?) in
            let accounts: [String: Account] = try UserAccount.allCombined(context: context)
            NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
            let exportAccounts = accounts.compactMapValues { (account) -> ExportAccount? in
                var tokenURL: String?
                if let token = try? account.oneTimePasswordToken() {
                    let queryItem = URLQueryItem(name: "secret", value: token.generator.secret.base32)
                    var queryComponents = try? URLComponents(url: token.toURL(), resolvingAgainstBaseURL: false)
                    queryComponents?.queryItems?.append(queryItem)
                    tokenURL = queryComponents?.url?.absoluteString
                }
                return ExportAccount(password: try? account.password(), notes: try? account.notes(), tokenURL: tokenURL)
            }
            try self.session.sendExportResponse(browserTab: self.browserTab, accounts: exportAccounts, context: context)
            return nil
        }.ensure {
            self.writeLog(isRejected: false)
            Logger.shared.analytics(.bulkLoginRequestAuthorized)
        }
    }

}
