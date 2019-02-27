/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import AVFoundation
import LocalAuthentication
import OneTimePassword

class PairViewController: QRViewController {

    var devicesDelegate: canReceiveSession?

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func handleURL(url: URL) throws {
        guard let scheme = url.scheme, scheme == "keyn" else {
            return
        }

        try AuthorizationGuard.shared.authorizePairing(url: url, completion: { [weak self] (session, error) in
            DispatchQueue.main.async {
                if let session = session {
                    self?.addSession(session: session)
                } else if let error = error {
                    switch error {
                    case KeychainError.storeKey:
                        Logger.shared.warning("This QR code was already scanned. Shouldn't happen here.", error: error)
                        self?.displayError(message: "errors.qr_scanned_twice".localized)
                    case SessionError.noEndpoint:
                        Logger.shared.error("There is no endpoint in the session data.", error: error)
                        self?.displayError(message: "errors.session_error_no_endpoint".localized)
                    default:
                        Logger.shared.error("Unhandled QR code error during pairing.", error: error)
                        self?.displayError(message: "errors.generic_error".localized)
                    }
                    self?.recentlyScannedUrls.removeAll(keepingCapacity: false)
                    self?.qrFound = false
                } else {
                    self?.recentlyScannedUrls.removeAll(keepingCapacity: false)
                    self?.qrFound = false
                }
            }
        })
    }

    // MARK: - Actions

    #warning("TODO: Check if there's a better way to check if the Pair View Controller is in the bottomNavigation or navigationcontroller")
    func addSession(session: Session) {
        if navigationController?.viewControllers[0] == self {
            let devicesVC = storyboard?.instantiateViewController(withIdentifier: "Devices Controller") as! DevicesViewController
            navigationController?.setViewControllers([devicesVC], animated: false)
        } else {
            devicesDelegate?.addSession(session: session)
            _ = navigationController?.popViewController(animated: true)
        }
    }

}
