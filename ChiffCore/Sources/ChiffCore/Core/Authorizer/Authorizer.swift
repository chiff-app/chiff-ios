//
//  Authorizer.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication
import OneTimePassword
import PromiseKit

public enum AuthorizationError: Error {
    case cannotChangeAccount
    case noTeamSessionFound
    case notAdmin
    case inProgress
    case unknownType
    case missingData
    case multipleAdminSessionsFound(count: Int)
}

extension AuthorizationError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .cannotChangeAccount:
            return "errors.authorization.shared_account_change".localized
        case .noTeamSessionFound:
            return "errors.authorization.no_team".localized
        case .notAdmin:
            return "errors.authorization.no_admin".localized
        case .multipleAdminSessionsFound(count: let count):
            return String(format: "errors.authorization.multiple_admins".localized, count)
        case .inProgress:
            return "errors.authorization.in_progress".localized
        case .missingData:
            return "errors.authorization.missing_data".localized
        case .unknownType:
            return "errors.authorization.unknown_type".localized
        }
    }
}

public protocol Authorizer {
    var session: BrowserSession { get set }
    var browserTab: Int { get }
    var type: ChiffMessageType { get }
    var authenticationReason: String { get }
    var requestText: String { get }
    var successText: String { get }
    var logParam: String { get }

    init(request: ChiffRequest, session: BrowserSession) throws

    /// Write a log entry for this request.
    func writeLog(isRejected: Bool)

    /// Start the authorization process to handle this request.
    /// - Parameter startLoading: This callback can be used for requests that may take a while to inform the user about the progress.
    func authorize(startLoading: ((_ status: String?) -> Void)?) -> Promise<Account?>
}

public extension Authorizer {

    func writeLog(isRejected: Bool) {
        let log = ChiffRequestLogModel(sessionId: session.id, param: logParam, type: type, browserTab: browserTab, isRejected: isRejected)
        ChiffRequestsLogStorage.sharedStorage.save(log: log)
    }

    /// Notifies the session client that this request is rejected.
    func rejectRequest() -> Guarantee<Void> {
        return cancelRequest(reason: .reject, error: nil)
    }

    /// Cancel a request.
    /// - Parameters:
    ///   - reason: The message type, should be either reject error
    ///   - error: Optionally, an error response.
    func cancelRequest(reason: ChiffMessageType, error: ChiffErrorResponse?) -> Guarantee<Void> {
        return firstly {
            session.cancelRequest(reason: reason, browserTab: browserTab, error: error)
        }.ensure {
            self.writeLog(isRejected: true)
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
