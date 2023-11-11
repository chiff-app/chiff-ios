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
                guard let password = try? account.password(),
                      let notes = try? account.notes(),
                      let token = try? account.oneTimePasswordToken() else {
                    return nil
                }
                return ExportAccount(password: password, notes: notes, tokenURL: try? token.toURL().absoluteString)
            }
            try self.session.sendExportResponse(browserTab: self.browserTab, accounts: exportAccounts, context: context)
            return nil
        }.ensure {
            self.writeLog(isRejected: false)
            Logger.shared.analytics(.bulkLoginRequestAuthorized)
        }
    }

}
