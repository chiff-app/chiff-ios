//
//  PairViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import AVFoundation
import LocalAuthentication
import OneTimePassword
import PromiseKit
import ChiffCore

protocol PairControllerDelegate: AnyObject {
    func sessionCreated(session: Session)
}

enum URLError: Error {
    case invalid
    case otp
}

class PairViewController: QRViewController {

    weak var pairControllerDelegate: PairControllerDelegate!
    weak var pairContainerDelegate: PairContainerDelegate!

    override func handleURL(url: URL) throws {
        var promise: Promise<Session>
        switch url.chiffType {
        case .pairing, .addUser:
            promise = self.pair(url: url)
        case .createTeam:
            promise = self.createTeam(url: url)
        case .otp:
            throw URLError.otp
        default:
            throw URLError.invalid
        }
        promise.done(on: .main) {
            self.createSession($0)
        }.catch(on: .main) {
            self.handleError($0)
        }
    }

    // MARK: - Private functions

    private func pair(url: URL) -> Promise<Session> {
        guard let parameters = url.queryParameters, let browser = parameters["b"]?.capitalizedFirstLetter, let os = parameters["o"]?.capitalizedFirstLetter else {
            return Promise(error: SessionError.invalid)
        }
        return firstly {
            AuthorizationGuard.shared.pair(parameters: parameters,
                                                       reason: "\("requests.pair_with".localized) \(browser) \("requests.on".localized) \(os).",
                                                       delegate: pairContainerDelegate)
        }
    }

    private func createTeam(url: URL) -> Promise<Session> {
        guard let parameters = url.queryParameters, let name = parameters["n"] else {
            return Promise(error: SessionError.invalid)
        }
        return firstly {
            AuthorizationGuard.shared.createTeam(parameters: parameters, reason: "\("requests.create_team".localized) \(name)", delegate: pairContainerDelegate)
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
        case URLError.otp:
            self.showAlert(message: "devices.otp_redirect".localized, handler: closeError)
        case SessionError.invalid:
            Logger.shared.error("Invalid QR-code scanned", error: error)
            self.showAlert(message: "errors.session_invalid".localized, handler: closeError)
        case SessionError.noEndpoint:
            Logger.shared.error("There is no endpoint in the session data.", error: error)
            self.showAlert(message: "errors.session_error_no_endpoint".localized, handler: closeError)
        case is APIError:
            self.showAlert(message: error.localizedDescription, handler: closeError)
        case let error as NSError where error.domain == NSURLErrorDomain:
            self.showAlert(message: error.localizedDescription, handler: closeError)
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
