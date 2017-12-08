import UIKit
import AVFoundation


class QRViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    // MARK: Properties
    
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var qrFound = false
    var isFirstSession = false
    @IBOutlet weak var videoView: UIView!
    var errorLabel: UILabel?
    var recentlyScannedUrls = [String]()

    enum CameraError: Error {
        case noCamera
        case videoInputInitFailed
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
           try scanQR()
        } catch {
            displayError(message: "Camera not available.")
            print("Camera could not be instantiated: \(error)")
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        qrFound = false
    }
    
    
    // MARK: Actions
    
    // TODO: is this still used?
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    
    // MARK: AVCaptureMetadataOutputObjectsDelegate
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if metadataObjects.count > 0 {
            let machineReadableCode = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
            if machineReadableCode.type == AVMetadataObject.ObjectType.qr {
                // TODO: Check if this can be exploited with specially crafted QR codes?
                if let urlString = machineReadableCode.stringValue, !qrFound {
                    decodeSessionData(url: urlString)
                }
            }
        } else { return }
    }
    
    
    // MARK: Private Methods

    private func displayError(message: String) {
        let errorLabel = UILabel(frame: CGRect(x: 0, y: 562, width: 375, height: 56))
        errorLabel.backgroundColor = UIColor.darkGray
        errorLabel.textColor = UIColor.white
        errorLabel.textAlignment = .center
        errorLabel.text = message
        errorLabel.alpha = 0.85
        view.addSubview(errorLabel)
        view.bringSubview(toFront: errorLabel)
        UIView.animate(withDuration: 3.0, delay: 1.0, options: [.curveLinear], animations: { errorLabel.alpha = 0.0 }, completion: { if $0 { errorLabel.removeFromSuperview() } })
    }

    private func decodeSessionData(url: String) {
        guard !recentlyScannedUrls.contains(url) else {
            displayError(message: "This QR code was already scanned.")
            return
        }
        if let parameters = URL(string: url)?.queryParameters, let pubKey = parameters["p"], let sqs = parameters["q"], let siteID = parameters["s"], let device = parameters["a"] {
            do {
                qrFound = true
                try SessionManager.sharedInstance.initiateSession(sqs: sqs, pubKey: pubKey, siteID: siteID, device: device)
                recentlyScannedUrls.append(url)
                DispatchQueue.main.async {
                    self.tabBarController?.selectedIndex = 2
                }
            } catch {
                switch error {
                case KeychainError.storeKey:
                    displayError(message: "This QR code was already scanned.")
                    qrFound = false
                default:
                    print("Unhandled error \(error)")
                    qrFound = false
                }
            }
        } else {
            displayError(message: "QR code could not be decoded.")
            qrFound = false

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

}
