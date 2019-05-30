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

class PairViewController: QRViewController {

    var pairControllerDelegate: PairControllerDelegate!
    var pairContainerDelegate: PairContainerDelegate!

    override func handleURL(url: URL) throws {
        guard let scheme = url.scheme, scheme == "keyn" else {
            return
        }

        self.pair(url: url)
    }

    private func pair(url: URL) {
        AuthorizationGuard.authorizePairing(url: url, authenticationCompletionHandler: {
            self.pairContainerDelegate.startLoading()
        }) { (session, error) in
            DispatchQueue.main.async {
                self.pairContainerDelegate.finishLoading()
                if let session = session {
                    self.pairControllerDelegate.sessionCreated(session: session)
                } else if let error = error {
                    self.hideIcon()
                    switch error {
                    case is LAError, is KeychainError:
                        if let authenticationError = LocalAuthenticationManager.shared.handleError(error: error) {
                             self.showError(message: authenticationError)
                        }
                    case SessionError.noEndpoint:
                        Logger.shared.error("There is no endpoint in the session data.", error: error)
                        self.showError(message: "errors.session_error_no_endpoint".localized)
                    case APIError.statusCode(let statusCode):
                        self.showError(message: "\("errors.api_error".localized): \(statusCode)")
                    case is APIError:
                        self.showError(message: "errors.api_error".localized)
                    default:
                        Logger.shared.error("Unhandled QR code error during pairing.", error: error)
                        self.showError(message: "errors.generic_error".localized)
                    }
                    self.recentlyScannedUrls.removeAll(keepingCapacity: false)
                    self.qrFound = false
                } else {
                    self.recentlyScannedUrls.removeAll(keepingCapacity: false)
                    self.qrFound = false
                }
            }
        }
    }

}
