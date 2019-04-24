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

class PairViewController: QRViewController {

    var pairControllerDelegate: PairControllerDelegate!

    override func handleURL(url: URL) throws {
        guard let scheme = url.scheme, scheme == "keyn" else {
            return
        }

        self.pair(url: url)
    }

    private func pair(url: URL) {
        AuthorizationGuard.authorizePairing(url: url) { (session, error) in
            DispatchQueue.main.async {
                if let session = session {
                    self.pairControllerDelegate.sessionCreated(session: session)
                } else if let error = error {
                    self.hideIcon()
                    switch error {
                    case KeychainError.storeKey:
                        Logger.shared.warning("This QR code was already scanned. Shouldn't happen here.", error: error)
                        self.showError(message: "errors.qr_scanned_twice".localized)
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
