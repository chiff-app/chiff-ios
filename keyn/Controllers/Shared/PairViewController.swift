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

enum URLError: Error {
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
            guard url.host == "keyn.app" || url.host == "chiff.app" else {
                throw URLError.invalidHost
            }
            guard url.pathComponents[1] == "adduser" || url.pathComponents[1] == "pair" else {
                throw URLError.invalidPath
            }
            promise = self.pair(url: url)
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
                self.showAlert(message: authenticationError, handler: closeError)
            }
        case SessionError.invalid:
            Logger.shared.error("Invalid QR-code scanned", error: error)
            self.showAlert(message: "errors.session_invalid".localized, handler: closeError)
        case SessionError.noEndpoint:
            Logger.shared.error("There is no endpoint in the session data.", error: error)
            self.showAlert(message: "errors.session_error_no_endpoint".localized, handler: closeError)
        case APIError.statusCode(let statusCode):
            self.showAlert(message: "\("errors.api_error".localized): \(statusCode)", handler: closeError)
        case is APIError:
            self.showAlert(message: "errors.api_error".localized, handler: closeError)
        default:
            Logger.shared.error("Unhandled QR code error during pairing.", error: error)
            self.showAlert(message: "errors.generic_error".localized, handler: closeError)
        }
    }

    private func closeError(_ action: UIAlertAction) {
        super.errorHandler(action)
        self.pairContainerDelegate.finishLoading()
    }

    private func removeNotifications() {
        if Properties.firstPairingCompleted { return }
        Properties.firstPairingCompleted = true
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: Properties.nudgeNotificationIdentifiers)
    }

}
