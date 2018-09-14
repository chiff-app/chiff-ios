import UIKit
import AVFoundation
import LocalAuthentication
import JustLog
import OneTimePassword

enum CameraError: Error {
    case noCamera
    case videoInputInitFailed
}

class QRViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    // MARK: Properties

    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var qrFound = false
    @IBOutlet weak var videoView: UIView!
    var errorLabel: UILabel?
    var recentlyScannedUrls = [String]()
    var devicesDelegate: canReceiveSession?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        qrFound = false
        do {
            try scanQR()
        } catch {
            displayError(message: "Camera not available.")
            Logger.shared.warning("Camera not available.", error: error as NSError)
        }
    }
    
    // MARK: AVCaptureMetadataOutputObjectsDelegate
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if metadataObjects.count > 0 {
            let machineReadableCode = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
            if machineReadableCode.type == AVMetadataObject.ObjectType.qr {
                // TODO: Check if this can be exploited with specially crafted QR codes?
                if let urlString = machineReadableCode.stringValue, !qrFound {
                    qrFound = true
                    do {
                        guard !recentlyScannedUrls.contains(urlString) else {
                            throw SessionError.exists
                        }
                        guard let url = URL(string: urlString) else {
                            throw SessionError.invalid
                        }
                        if let scheme = url.scheme {
                            if scheme == "keyn" {
                                try pairPermission(url: url)
                            } else if scheme == "otpauth" {
                                try addOTP(url: url)
                            }
                        }
                    } catch {
                        switch error {
                        case SessionError.exists:
                            Logger.shared.debug("Qr-code scanned twice.")
                            displayError(message: "This QR-code was already scanned.")
                        case SessionError.invalid:
                            Logger.shared.warning("Invalid QR code scanned", error: error as NSError)
                            displayError(message: "This QR-code could not be decoded.")
                        default:
                            Logger.shared.error("Unhandled QR code error.", error: error as NSError)
                        }
                        qrFound = false
                    }
                }
            }
        } else { return }
    }
    
    // MARK: Private Methods
    
    private func displayError(message: String) {
        let errorLabel = UILabel(frame: CGRect(x: 0, y: 562, width: 375, height: 56))
        errorLabel.backgroundColor = UIColor.white
        errorLabel.textAlignment = .center
        errorLabel.text = message
        errorLabel.alpha = 0.85
        view.addSubview(errorLabel)
        view.bringSubview(toFront: errorLabel)
        UIView.animate(withDuration: 3.0, delay: 1.0, options: [.curveLinear], animations: { errorLabel.alpha = 0.0 }, completion: { if $0 { errorLabel.removeFromSuperview() } })
    }
    
    private func scanQR() throws {
        
        guard let captureDevice = AVCaptureDevice.default(for: .video) else {
            throw CameraError.noCamera
        }
        
        guard let input = try? AVCaptureDeviceInput(device: captureDevice) else {
            throw CameraError.videoInputInitFailed
        }
        
        let captureSession = AVCaptureSession()
        captureSession.addInput(input)
        
        let captureMetadataOutput = AVCaptureMetadataOutput()
        captureSession.addOutput(captureMetadataOutput)
        
        captureMetadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue.main)
        captureMetadataOutput.metadataObjectTypes = [AVMetadataObject.ObjectType.qr]
        
        previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        previewLayer?.videoGravity = AVLayerVideoGravity.resizeAspectFill
        previewLayer?.frame = view.layer.bounds
        videoView.layer.addSublayer(previewLayer!)
        
        captureSession.startRunning()
    }
    
    private func addOTP(url: URL) throws {
        if let token = Token(url: url) {
            try AuthenticationGuard.sharedInstance.addOTP(token: token, completion: { [weak self] (account, error) in
                DispatchQueue.main.async {
                    if account != nil {
                        do {
                            var account = account
                            if account?.hasOtp ?? false {
                                try account!.updateOtp(token: token)
                            } else {
                                try account!.addOtp(token: token)
                            }
                        } catch {
                            Logger.shared.error("Error adding OTP", error: error as NSError)
                        }
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
        } else {
            print("Invalid token URL")
        }
    }
    
    private func pairPermission(url: URL) throws {
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
