//
//  AuthorizationGuard.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import OneTimePassword
import LocalAuthentication
import PromiseKit
import ChiffCore

extension AuthorizationGuard {
    /// Launch a the RequestViewController with the appropriate `Authorizer`.
    /// - Parameter request: The `ChiffRequest` that has been received.
    func launchRequestView(with request: ChiffRequest) {
        guard !authorizationInProgress else {
            return
        }
        authorizationInProgress = true
        do {
            guard let sessionID = request.sessionID, let session = try BrowserSession.get(id: sessionID, context: nil) else {
                authorizationInProgress = false
                throw SessionError.doesntExist
            }
            let storyboard: UIStoryboard = UIStoryboard.get(.request)
            guard let viewController = storyboard.instantiateViewController(withIdentifier: "PasswordRequest") as? RequestViewController else {
                throw TypeError.wrongViewControllerType
            }
            viewController.authorizer = try createAuthorizer(request: request, session: session)
            UIApplication.shared.visibleViewController?.present(viewController, animated: true, completion: nil)
        } catch {
            authorizationInProgress = false
            Logger.shared.error("Could not decode session.", error: error)
        }
    }
    /// Create a new Team. This can be used to create a Team / Organization by scanning a QR-code.
    /// - Parameters:
    ///   - parameters: The URL-parameters of the URL that was scanned.
    ///   - reason: The authentication reason that is presented to the user.
    ///   - delegate: The delegate to update the UI.
    /// - Returns: The Promise of a Session.
    func createTeam(parameters: [String: String], reason: String, delegate: PairContainerDelegate) -> Promise<Session> {
        guard !authorizationInProgress else {
            return Promise(error: AuthorizationError.inProgress)
        }
        authorizationInProgress = true
        return firstly {
            LocalAuthenticationManager.shared.authenticate(reason: reason, withMainContext: false)
        }.then { _ -> Promise<Session> in
            delegate.startLoading()
            Logger.shared.analytics(.qrCodeScanned, properties: [.value: true])
            guard let orderKey = parameters["k"], let name = parameters["n"] else {
                throw SessionError.invalid
            }
            let team = try Team(name: name)
            return team.create(orderKey: orderKey)
        }.ensure {
            self.authorizationInProgress = false
        }
    }

    /// Redirect the user to a ViewController that shows an error message. This is used only for errors that put the app in a state that cannot be fixed.
    /// - Parameter errorMessage: The error message that should be displayed.
    func showError(errorMessage: String) {
        DispatchQueue.main.async {
            guard let viewController = UIStoryboard.main.instantiateViewController(withIdentifier: "ErrorViewController") as? ErrorViewController else {
                Logger.shared.error("Can't create ErrorViewController so we have no way to start the app.")
                return
            }

            viewController.errorMessage = errorMessage
            UIApplication.shared.visibleViewController?.present(viewController, animated: true, completion: nil)
        }
    }

    func createAuthorizer(request: ChiffRequest, session: BrowserSession) throws -> Authorizer {
        switch request.type {
        case .add, .register, .addAndLogin:
            return try AddSiteAuthorizer(request: request, session: session)
        case .addToExisting:
            return try AddToExistingAuthorizer(request: request, session: session)
        case .addBulk:
            return try AddBulkSiteAuthorizer(request: request, session: session)
        case .change:
            return try ChangeAuthorizer(request: request, session: session)
        case .login, .fill, .getDetails:
            return try LoginAuthorizer(request: request, session: session)
        case .bulkLogin:
            return try BulkLoginAuthorizer(request: request, session: session)
        case .adminLogin:
            return try TeamAdminLoginAuthorizer(request: request, session: session)
        case .webauthnCreate:
            return try WebAuthnRegistrationAuthorizer(request: request, session: session)
        case .webauthnLogin:
            return try WebAuthnLoginAuthorizer(request: request, session: session)
        case .updateAccount:
            return try UpdateAccountAuthorizer(request: request, session: session)
        case .createOrganisation:
            return try CreateOrganisationAuthorizer(request: request, session: session)
        default:
            throw AuthorizationError.unknownType
        }
    }

}
