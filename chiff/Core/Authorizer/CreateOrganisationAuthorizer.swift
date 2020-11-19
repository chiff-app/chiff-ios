//
//  AddSiteAuthorizer.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import LocalAuthentication
import PromiseKit

class CreateOrganisationAuthorizer: Authorizer {
    var session: BrowserSession
    let type = ChiffMessageType.createOrganisation
    let browserTab: Int
    let organisationName: String
    let orderKey: String

    let requestText = "requests.create_team".localized.capitalizedFirstLetter
    let successText = "requests.team_created".localized.capitalizedFirstLetter
    var authenticationReason: String {
        return String(format: "requests.create_this".localized, organisationName)
    }

    required init(request: ChiffRequest, session: BrowserSession) throws {
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
            let team = try Team(name: self.organisationName)
            return team.create(orderKey: self.orderKey).map { ($0, team.seed.base64, context) }
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
        }.ensure {
            Logger.shared.analytics(.createOrganisationRequestAuthorized)
        }.log("Error creating team")
    }

}
