import UIKit
import AVFoundation


class QRViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    // MARK: Properties
    
    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var delegate: isAbleToReceiveData?
    var qrFound = false
    var isFirstSession = false
    @IBOutlet weak var videoView: UIView!
    var errorLabel: UILabel?

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
    
    
    // MARK: Actions
    
    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    
    // MARK: AVCaptureMetadataOutputObjectsDelegate
    
    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if metadataObjects.count > 0 {
            let machineReadableCode = metadataObjects[0] as! AVMetadataMachineReadableCodeObject
            if machineReadableCode.type == AVMetadataObject.ObjectType.qr {
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
        if let parameters = URL(string: url)?.queryParameters, let pubKey = parameters["p"], let nonce = parameters["n"], let sqs = parameters["s"], let sqsURL = URL(string: "http://sqs.us-east-2.amazonaws.com/" + sqs) {
            let session = Session(sqs: sqsURL, nonce: nonce, pubKey: pubKey)
            qrFound = true
            delegate?.addSession(session: session)
            if isFirstSession {
                _ = navigationController?.popViewController(animated: false)
            } else {
                dismiss(animated: true, completion: nil)
            }
        } else {
            displayError(message: "QR code could not be decoded.")
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

extension URL {

    public var queryParameters: [String: String]? {
        guard let components = URLComponents(url: self, resolvingAgainstBaseURL: true), let queryItems = components.queryItems else {
            return nil
        }

        var parameters = [String: String]()
        for item in queryItems {
            parameters[item.name] = item.value
        }

        return parameters
    }
}