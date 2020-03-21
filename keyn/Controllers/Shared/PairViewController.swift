/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import AVFoundation
import LocalAuthentication
import OneTimePassword
import PromiseKit

protocol PairControllerDelegate {
    func sessionCreated(session: Session)
}

protocol PairContainerDelegate {
    func startLoading()
    func finishLoading()
}

enum URLError: KeynError {
    case invalidScheme
    case invalidHost
    case invalidPath
}

class PairViewController: QRViewController {

    var pairControllerDelegate: PairControllerDelegate!
    var pairContainerDelegate: PairContainerDelegate!

    override func handleURL(url: URL) throws {
        var promise: Promise<Session>
        switch url.scheme {
        case "keyn":
            promise = self.pair(url: url)
        case "https":
            guard url.host == "keyn.app" else {
                throw URLError.invalidHost
            }

            switch url.pathComponents[1] {
            case "adduser", "pair":
                promise = self.pair(url: url)
            case "team":
                switch url.pathComponents[2] {
                case "create":
                    promise = self.createTeam(url: url)
                case "restore":
                    promise = self.restoreTeam(url: url)
                default: throw URLError.invalidPath
                }
            default: throw URLError.invalidPath
            }
        default: throw URLError.invalidScheme
        }
        promise.done(on: .main) {
            self.createSession($0)
        }.catch(on: .main) {
            self.handleError($0)
        }
    }

    private func pair(url: URL) -> Promise<Session> {
        guard let parameters = url.queryParameters, let browser = parameters["b"]?.capitalizedFirstLetter, let os = parameters["o"]?.capitalizedFirstLetter else {
            return Promise(error: SessionError.invalid)
        }
        return firstly {
            AuthorizationGuard.startAuthorization(reason: "\("requests.pair_with".localized) \(browser) \("requests.on".localized) \(os).")
        }.then(on: .main) { context -> Promise<Session> in
            self.pairContainerDelegate.startLoading()
            Logger.shared.analytics(.qrCodeScanned, properties: [.value: true])
            return AuthorizationGuard.authorizePairing(parameters: parameters, context: context)
        }
    }

    private func createTeam(url: URL) -> Promise<Session> {
        return firstly {
            AuthorizationGuard.startAuthorization(reason: "requests.create_team".localized)
        }.then(on: .main) { context -> Promise<Session> in
            self.pairContainerDelegate.startLoading()
            guard let parameters = url.queryParameters, let token = parameters["t"], let name = parameters["n"] else {
                return Promise(error: SessionError.invalid)
            }
            return Team.create(token: token, name: name)
        }
    }

    private func restoreTeam(url: URL) -> Promise<Session> {
        return firstly {
            AuthorizationGuard.startAuthorization(reason: "requests.restore_team".localized)
        }.then(on: .main) { context -> Promise<Session> in
            self.pairContainerDelegate.startLoading()
            guard let parameters = url.queryParameters, let seed = parameters["s"] else {
                return Promise(error: SessionError.invalid)
            }
            return Team.restore(teamSeed64: seed)
        }
    }

    private func createSession(_ session: Session) {
        self.pairContainerDelegate.finishLoading()
        self.pairControllerDelegate.sessionCreated(session: session)
        Logger.shared.analytics(.paired)
        self.removeNotifications()
    }
    
    private func handleError(_ error: Error) {
        switch error {
        case is LAError, is KeychainError:
            if let authenticationError = LocalAuthenticationManager.shared.handleError(error: error) {
                self.showAlert(message: authenticationError, handler: super.errorHandler)
            }
        case SessionError.invalid:
            Logger.shared.error("Invalid QR-code scanned", error: error)
            self.showAlert(message: "errors.session_invalid".localized, handler: super.errorHandler)
        case SessionError.noEndpoint:
            Logger.shared.error("There is no endpoint in the session data.", error: error)
            self.showAlert(message: "errors.session_error_no_endpoint".localized, handler: super.errorHandler)
        case APIError.statusCode(let statusCode):
            self.showAlert(message: "\("errors.api_error".localized): \(statusCode)", handler: super.errorHandler)
        case is APIError:
            self.showAlert(message: "errors.api_error".localized, handler: super.errorHandler)
        default:
            Logger.shared.error("Unhandled QR code error during pairing.", error: error)
            self.showAlert(message: "errors.generic_error".localized, handler: super.errorHandler)
        }
    }

    private func removeNotifications() {
        if Properties.firstPairingCompleted { return }
        Properties.firstPairingCompleted = true
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: Properties.nudgeNotificationIdentifiers)
    }

}
