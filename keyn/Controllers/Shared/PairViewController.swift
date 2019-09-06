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
        guard (url.host == "keyn.app" && url.path == "/pair") || url.scheme == "keyn"  else {
            Logger.shared.analytics(.qrCodeScanned, properties: [
                .value: false,
                .scheme: url.scheme ?? "no scheme"
            ])
            showError(message: "errors.session_invalid".localized)
            return
        }
        Logger.shared.analytics(.qrCodeScanned, properties: [.value: true])
        self.pair(url: url)
    }

    private func pair(url: URL) {
        AuthorizationGuard.authorizePairing(url: url, authenticationCompletionHandler: {
            self.pairContainerDelegate.startLoading()
        }) { (result) in
            DispatchQueue.main.async {
                self.pairContainerDelegate.finishLoading()
                switch result {
                case .success(let session):
                    self.pairControllerDelegate.sessionCreated(session: session)
                    Logger.shared.analytics(.paired)
                case .failure(let error):
                    self.hideIcon()
                    switch error {
                    case is LAError, is KeychainError:
                        if let authenticationError = LocalAuthenticationManager.shared.handleError(error: error) {
                            self.showError(message: authenticationError)
                        }
                    case SessionError.invalid:
                        Logger.shared.error("Invalid QR-code scanned", error: error)
                        self.showError(message: "errors.session_invalid".localized)
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
                }
            }
        }
    }

}
