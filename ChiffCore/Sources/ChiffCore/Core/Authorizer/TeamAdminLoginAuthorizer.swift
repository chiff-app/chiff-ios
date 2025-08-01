//
//  AddSiteAuthorizer.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

public class TeamAdminLoginAuthorizer: Authorizer {
    public var session: BrowserSession
    public let type = ChiffMessageType.adminLogin
    public let browserTab: Int
    public let code: String?

    public var requestText: String {
        return String(format: "requests.confirm_login".localized.capitalizedFirstLetter, session.title)
    }
    public let successText = "requests.login_succesful".localized.capitalizedFirstLetter
    public var authenticationReason: String {
        return String(format: "requests.login_to".localized, "requests.chiff_for_teams".localized)
    }
    public var verify: Bool {
        return code != nil
    }
    public var verifyText: String? {
        return String(format: "requests.verify_login".localized, "requests.chiff_for_teams".localized)
    }
    public var teamSession: TeamSession?
    public var logParam: String = ""

    public required init(request: ChiffRequest, session: BrowserSession) throws {
        self.session = session
        guard let browserTab = request.browserTab else {
            throw AuthorizationError.missingData
        }
        self.code = request.verificationCode
        self.browserTab = browserTab
        Logger.shared.analytics(.adminLoginRequestOpened)
    }

    public func authorize(verification: String?, startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        guard let teamSession = teamSession else {
            return Promise(error: AuthorizationError.notAdmin)
        }
        self.logParam = teamSession.title
        return firstly {
            self.authenticate(verification: verification)
        }.then { context -> Promise<(Data, LAContext?)> in
            startLoading?(nil)
            return teamSession.getTeamSeed().map { ($0, context) }
        }.then { seed, context  in
            self.session.sendTeamSeed(id: teamSession.id, teamId: teamSession.teamId, seed: seed.base64, browserTab: self.browserTab, context: context!, organisationKey: nil).map { nil }
        }.ensure {
            self.writeLog(isRejected: false)
            Logger.shared.analytics(.adminLoginRequestAuthorized)
        }.log("Error getting admin seed")
    }
    
}
