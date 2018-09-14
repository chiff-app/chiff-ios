import UIKit
import AVFoundation
import LocalAuthentication
import JustLog
import OneTimePassword

class PairViewController: QRViewController {
    
    var devicesDelegate: canReceiveSession?
    
    override func handleURL(url: URL) throws {
        guard let scheme = url.scheme, scheme == "keyn" else {
            return
        }
        try AuthenticationGuard.sharedInstance.authorizePairing(url: url, completion: { [weak self] (session, error) in
            DispatchQueue.main.async {
                if let session = session {
                    self?.add(session: session)
                } else if let error = error {
                    switch error {
                    case KeychainError.storeKey:
                        Logger.shared.warning("This QR code was already scanned. Shouldn't happen here.", error: error as NSError)
                        self?.displayError(message: "This QR code was already scanned.")
                    default:
                        Logger.shared.error("Unhandled QR code error.", error: error as NSError)
                        self?.displayError(message: "An error occured.")
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
    
    func add(session: Session) {
        if navigationController?.viewControllers[0] == self {
            let devicesVC = storyboard?.instantiateViewController(withIdentifier: "Devices Controller") as! DevicesViewController
            navigationController?.setViewControllers([devicesVC], animated: false)
        } else {
            devicesDelegate?.addSession(session: session)
            _ = navigationController?.popViewController(animated: true)
        }
    }

}
