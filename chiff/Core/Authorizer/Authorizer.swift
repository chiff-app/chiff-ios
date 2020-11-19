//
//  Authorizer.swift
//  chiff
//
//  Copyright: see LICENSE.md
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
    var type: ChiffMessageType { get }
    var authenticationReason: String { get }
    var requestText: String { get }
    var successText: String { get }

    init(request: ChiffRequest, session: BrowserSession) throws

    /// Start the authorization process to handle this request.
    /// - Parameter startLoading: This callback can be used for requests that may take a while to inform the user about the progress.
    func authorize(startLoading: ((_ status: String?) -> Void)?) -> Promise<Account?>
}

extension Authorizer {

    /// Notifies the session client that this request is rejected.
    func rejectRequest() -> Guarantee<Void> {
        return firstly {
            session.cancelRequest(reason: .reject, browserTab: browserTab)
        }.ensure {
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
