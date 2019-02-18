/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import AVFoundation
import LocalAuthentication

enum CameraError: KeynError {
    case noCamera
    case videoInputInitFailed
}

class QRViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    @IBOutlet weak var videoView: UIView!
    
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var qrFound = false
    var errorLabel: UILabel?
    var recentlyScannedUrls = [String]()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        qrFound = false
        do {
            try scanQR()
        } catch {
            displayError(message: "errors.no_camera".localized)
            Logger.shared.warning("Camera not available.", error: error)
        }
    }
    
    func handleURL(url: URL) throws {
        preconditionFailure("This method must be overridden")
    }
    
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
                        try handleURL(url: url)
                    } catch {
                        switch error {
                        case SessionError.exists:
                            Logger.shared.debug("QR-code scanned twice.")
                            displayError(message: "errors.qr_scanned_twice".localized)
                        case SessionError.invalid:
                            Logger.shared.warning("Invalid QR code scanned", error: error)
                            displayError(message: "errors.undecodable_qr".localized)
                        default:
                            Logger.shared.error("Unhandled QR code error.", error: error)
                        }
                        qrFound = false
                    }
                }
            }
        } else {
            return
        }
    }
    
    func displayError(message: String) {
        let errorLabel = UILabel(frame: CGRect(x: 0, y: 562, width: 375, height: 56))
        errorLabel.backgroundColor = UIColor.white
        errorLabel.textAlignment = .center
        errorLabel.text = message
        errorLabel.alpha = 0.85

        view.addSubview(errorLabel)
        view.bringSubviewToFront(errorLabel)

        UIView.animate(withDuration: 3.0, delay: 1.0, options: [.curveLinear], animations: { errorLabel.alpha = 0.0 }, completion: { if $0 { errorLabel.removeFromSuperview() } })
    }
    
    func scanQR() throws {
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
}
