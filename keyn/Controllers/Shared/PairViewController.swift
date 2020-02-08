/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import AVFoundation
import LocalAuthentication
import OneTimePassword

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
        switch url.scheme {
        case "keyn": self.pair(url: url)
        case "https":
            guard url.host == "keyn.app" else {
                throw URLError.invalidHost
            }
            switch url.pathComponents[1] {
            case "adduser", "pair": self.pair(url: url)
            case "team":
                switch url.pathComponents[2] {
                case "create": self.createTeam(url: url)
                case "restore": self.restoreTeam(url: url)
                default: throw URLError.invalidPath
                }
            default: throw URLError.invalidPath
            }
        default: throw URLError.invalidScheme
        }
    }

    private func pair(url: URL) {
        Logger.shared.analytics(.qrCodeScanned, properties: [.value: true])
        AuthorizationGuard.authorizePairing(url: url, authenticationCompletionHandler: { _ in
            DispatchQueue.main.async {
                self.pairContainerDelegate.startLoading()
            }
        }, completionHandler: createSession)
    }

    private func createTeam(url: URL) {
        AuthorizationGuard.authorizeTeamCreation(url: url, authenticationCompletionHandler: { _ in
            DispatchQueue.main.async {
                self.pairContainerDelegate.startLoading()
            }
        }, completionHandler: createSession)
    }

    private func restoreTeam(url: URL) {
        AuthorizationGuard.authorizeTeamRestore(url: url, authenticationCompletionHandler: { _ in
            DispatchQueue.main.async {
                self.pairContainerDelegate.startLoading()
            }
        }, completionHandler: createSession)
    }

    private func createSession(_ result: Result<Session, Error>) {
        DispatchQueue.main.async {
            self.pairContainerDelegate.finishLoading()
            switch result {
            case .success(let session):
                self.pairControllerDelegate.sessionCreated(session: session)
                Logger.shared.analytics(.paired)
                self.removeNotifications()
            case .failure(let error):
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
        }
    }

    private func removeNotifications() {
        if Properties.firstPairingCompleted { return }
        Properties.firstPairingCompleted = true
        let notificationCenter = UNUserNotificationCenter.current()
        notificationCenter.removePendingNotificationRequests(withIdentifiers: Properties.nudgeNotificationIdentifiers)
    }

}
