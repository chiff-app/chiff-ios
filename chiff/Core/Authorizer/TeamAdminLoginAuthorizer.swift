//
//  AddSiteAuthorizer.swift
//  keyn
//
//  Created by Bas Doorn on 22/10/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import LocalAuthentication
import PromiseKit

class TeamAdminLoginAuthorizer: Authorizer {
    var session: BrowserSession
    let type = KeynMessageType.adminLogin
    let browserTab: Int

    let requestText = "requests.confirm_login".localized.capitalizedFirstLetter
    let successText = "requests.login_succesful".localized.capitalizedFirstLetter
    var authenticationReason: String {
        return String(format: "requests.login_to".localized, "requests.keyn_for_teams".localized)
    }

    required init(request: KeynRequest, session: BrowserSession) throws {
        self.session = session
        guard let browserTab = request.browserTab else {
            throw AuthorizationError.missingData
        }
        self.browserTab = browserTab
        Logger.shared.analytics(.adminLoginRequestOpened)
    }

    func authorize(startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        guard let teamSession = try? TeamSession.all().first else {
            AuthorizationGuard.shared.showError(errorMessage: "errors.session_not_found".localized)
            return .value(nil)
        } // TODO: What if there's more than 1?
        guard teamSession.isAdmin else {
            AuthorizationGuard.shared.showError(errorMessage: "errors.only_admins".localized)
            return .value(nil)
        }
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false)
        }.then { context -> Promise<(Data, LAContext?)> in
            startLoading?(nil)
            return teamSession.getTeamSeed().map { ($0, context) }
        }.then { seed, context  in
            self.session.sendTeamSeed(id: teamSession.id, teamId: teamSession.teamId, seed: seed.base64, browserTab: self.browserTab, context: context!, organisationKey: nil).map { nil }
        }.ensure {
            Logger.shared.analytics(.adminLoginRequestAuthorized)
        }.log("Error getting admin seed")
    }

}
