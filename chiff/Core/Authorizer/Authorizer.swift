//
//  Authorizer.swift
//  keyn
//
//  Created by Bas Doorn on 22/10/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import UIKit
import OneTimePassword
import LocalAuthentication
import PromiseKit

enum AuthorizationError: Error {
    case cannotChangeAccount
    case noTeamSessionFound
    case notAdmin
    case inProgress
    case unknownType
    case missingData
    case multipleAdminSessionsFound(count: Int)
}

protocol Authorizer {
    var session: BrowserSession { get set }
    var browserTab: Int { get }
    var type: KeynMessageType { get }
    var authenticationReason: String { get }
    var requestText: String { get }
    var successText: String { get }

    init(request: KeynRequest, session: BrowserSession) throws

    func authorize(startLoading: ((_ status: String?) -> Void)?) -> Promise<Account?>
}

extension Authorizer {

    func rejectRequest() -> Guarantee<Void> {
        return firstly {
            session.cancelRequest(reason: .reject, browserTab: browserTab)
        }.asVoid().ensure {
            AuthorizationGuard.shared.authorizationInProgress = false
        }.recover { error in
            Logger.shared.error("Reject message could not be sent.", error: error)
            return
        }
    }

    var succesDetailText: String {
        switch type {
        case .add, .addAndLogin, .webauthnCreate, .addBulk:
            return "requests.login_keyn_next_time".localized.capitalizedFirstLetter
        default:
            return "requests.return_to_computer".localized.capitalizedFirstLetter

        }
    }

}
