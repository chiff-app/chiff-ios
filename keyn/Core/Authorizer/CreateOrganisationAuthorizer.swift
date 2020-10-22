//
//  AddSiteAuthorizer.swift
//  keyn
//
//  Created by Bas Doorn on 22/10/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import LocalAuthentication
import PromiseKit

class CreateOrganisationAuthorizer: Authorizer {
    var session: BrowserSession
    let type = KeynMessageType.createOrganisation
    let browserTab: Int
    let organisationName: String
    let orderKey: String

    let requestText = "requests.create_team".localized.capitalizedFirstLetter
    let successText = "requests.team_created".localized.capitalizedFirstLetter
    var authenticationReason: String {
        return String(format: "requests.create_this".localized, organisationName)
    }

    required init(request: KeynRequest, session: BrowserSession) throws {
        self.session = session
        guard let browserTab = request.browserTab,
              let organisationName = request.organisationName,
              let orderKey = request.orderKey else {
            throw AuthorizationError.missingData
        }
        self.browserTab = browserTab
        self.organisationName = organisationName
        self.orderKey = orderKey
        Logger.shared.analytics(.createOrganisationRequestOpened)
    }

    func authorize(startLoading: ((String?) -> Void)?) -> Promise<Account?> {
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: self.authenticationReason, withMainContext: false)
        }.then { (context) -> Promise<(Session, String, LAContext?)> in
            startLoading?(nil)
            return Team.create(orderKey: self.orderKey, name: self.organisationName).map { ($0, $1, context) }
        }.then { (teamSession, seed, context) -> Promise<Account?> in
            NotificationCenter.default.postMain(Notification(name: .sessionStarted, object: nil, userInfo: ["session": teamSession]))
            guard let teamSession = teamSession as? TeamSession else {
                throw AuthorizationError.noTeamSessionFound
            }
            return self.session.sendTeamSeed(id: teamSession.id,
                                             teamId: teamSession.teamId,
                                             seed: seed,
                                             browserTab: self.browserTab,
                                             context: context!,
                                             organisationKey: teamSession.organisationKey.base64).map { nil }
        }.ensure{
            Logger.shared.analytics(.createOrganisationRequestAuthorized)
        }.log("Error creating team")
    }

}
