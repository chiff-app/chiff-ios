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
    var isInitialSetup = true

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    override func handleURL(url: URL) throws {
        guard let scheme = url.scheme, scheme == "keyn" else {
            return
        }

        if isInitialSetup {
            try initializeSeed { [weak self] (result) in
                if result {
                    self?.pair(url: url)
                    Logger.shared.analytics("Seed created", code: .seedCreated)
                } else {
                    self?.displayError(message: "Error creating backup entry")
                }
            }
        } else {
            pair(url: url)
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
                    NotificationCenter.default.post(name: .sessionStarted, object: nil, userInfo: ["session": session])
                    if self.isInitialSetup {
                        self.showRootController()
                    } else {
                        print("TODO")
                    }
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

    private func showRootController() {
        guard let window = UIApplication.shared.keyWindow else {
            return
        }
        guard let vc = UIStoryboard.main.instantiateViewController(withIdentifier: "RootController") as? RootViewController else {
            Logger.shared.error("Unexpected root view controller type")
            fatalError("Unexpected root view controller type")
        }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            DispatchQueue.main.async {
                window.rootViewController = vc
            }
        })
    }

    // MARK: - Actions

    @IBAction func tryLater(_ sender: UIButton) {
        do {
            guard isInitialSetup else {
                print("todo")
                return
            }
            try initializeSeed { [weak self] (result) in
                DispatchQueue.main.async {
                    guard result else {
                        self?.displayError(message: "Error creating backup entry")
                        return
                    }
                    self?.showRootController()
                }
            }
        } catch {
            print(error)
            displayError(message: "Error creating seed")
        }
    }
    
}
