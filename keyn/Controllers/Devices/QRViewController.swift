import UIKit
import AVFoundation
import LocalAuthentication
import JustLog

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
                if let url = machineReadableCode.stringValue, !qrFound {
                    qrFound = true
                    if let parameters = URL(string: url)?.queryParameters, let pubKey = parameters["p"], let messageSqs = parameters["mq"], let controlSqs = parameters["cq"], let browser = parameters["b"], let os = parameters["o"]{
                        do {
                            guard try !recentlyScannedUrls.contains(url) && !Session.exists(sqs: messageSqs, browserPublicKey: pubKey) else {
                                Logger.shared.debug("Qr-code scanned twice.")
                                displayError(message: "This QR-code was already scanned.")
                                qrFound = false
                                return
                            }
                        } catch {
                            Logger.shared.warning("Invalid QR code scanned", error: error as NSError)
                            displayError(message: "This QR-code could not be decoded.")
                            qrFound = false
                            return
                        }
                        recentlyScannedUrls.append(url)
                        DispatchQueue.main.async {
                            self.pairPermission(pubKey: pubKey, messageSqs: messageSqs, controlSqs: controlSqs, browser: browser, os: os)
                        }
                    } else {
                        Logger.shared.warning("Invalid QR code scanned")
                        displayError(message: "This QR-code could not be decoded.")
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
    
    private func decodeSessionData(pubKey: String, messageSqs: String, controlSqs: String, browser: String, os: String) {
        do {
            let session = try Session.initiate(sqsMessageQueue: messageSqs, sqsControlQueue: controlSqs, pubKey: pubKey, browser: browser, os: os)
            if navigationController?.viewControllers[0] == self {
                let devicesVC = storyboard?.instantiateViewController(withIdentifier: "Devices Controller") as! DevicesViewController
                navigationController?.setViewControllers([devicesVC], animated: false)
            } else {
                devicesDelegate?.addSession(session: session)
                _ = navigationController?.popViewController(animated: true)
            }
        } catch {
            switch error {
            case KeychainError.storeKey:
                Logger.shared.warning("This QR code was already scanned. Shouldn't happen here.", error: error as NSError)
                displayError(message: "This QR code was already scanned.")
                qrFound = false
            default:
                Logger.shared.error("Unhandled QR code error.", error: error as NSError)
                qrFound = false
            }
        }
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
    
    private func pairPermission(pubKey: String, messageSqs: String, controlSqs: String, browser: String, os: String) {
        let authenticationContext = LAContext()
        var error: NSError?
        
        guard authenticationContext.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            Logger.shared.error("TODO: Handle fingerprint absence.", error: error)
            return
        }
        
        authenticationContext.evaluatePolicy(
            .deviceOwnerAuthenticationWithBiometrics,
            localizedReason: "Pair with \(browser) on \(os).",
            reply: { [weak self] (success, error) -> Void in
                Logger.shared.info("Pairing response.", userInfo: ["code": AnalyticsMessage.pairResponse.rawValue, "result": success])
                if (success) {
                    DispatchQueue.main.async {
                        self?.decodeSessionData(pubKey: pubKey, messageSqs: messageSqs, controlSqs: controlSqs, browser: browser, os: os)
                    }
                } else {
                    self?.recentlyScannedUrls.removeLast()
                    self?.qrFound = false
                }
            }
        )
    }

}
