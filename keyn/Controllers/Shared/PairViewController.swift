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
    func prepareForPairing(completionHandler: @escaping (_ result: Bool) -> Void)
}

class PairViewController: QRViewController {

    var pairControllerDelegate: PairControllerDelegate!

    override func handleURL(url: URL) throws {
        guard let scheme = url.scheme, scheme == "keyn" else {
            return
        }

        pairControllerDelegate.prepareForPairing { (result) in
            if result {
                self.pair(url: url)
            }
        }
    }

    // MARK: - Private functions

    private func initializeSeed(completionHandler: @escaping (_: Bool) -> Void) throws {
        try Seed.create()
        try BackupManager.shared.initialize(completionHandler: completionHandler)
    }

    private func pair(url: URL) {
        AuthorizationGuard.authorizePairing(url: url) { [weak self] (session, error) in
            DispatchQueue.main.async {
                guard let self = self else {
                    return
                }
                if let session = session {
                    self.pairControllerDelegate.sessionCreated(session: session)
                } else if let error = error {
                    switch error {
                    case KeychainError.storeKey:
                        Logger.shared.warning("This QR code was already scanned. Shouldn't happen here.", error: error)
                        self.displayError(message: "errors.qr_scanned_twice".localized)
                    case SessionError.noEndpoint:
                        Logger.shared.error("There is no endpoint in the session data.", error: error)
                        self.displayError(message: "errors.session_error_no_endpoint".localized)
                    default:
                        Logger.shared.error("Unhandled QR code error during pairing.", error: error)
                        self.displayError(message: "errors.generic_error".localized)
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
