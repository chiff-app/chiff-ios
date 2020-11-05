//
//  QRViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import AVFoundation
import LocalAuthentication

enum CameraError: Error {
    case noCamera
    case videoInputInitFailed
    case exists
    case invalid
    case unknown
}

class QRViewController: UIViewController, AVCaptureMetadataOutputObjectsDelegate {

    @IBOutlet weak var videoView: UIView!
    @IBOutlet weak var qrIconImageView: UIImageView!
    @IBOutlet weak var scanCheckmarkImageView: UIImageView!

    var captureSession: AVCaptureSession?
    var previewLayer: AVCaptureVideoPreviewLayer?
    var qrFound = false
    var errorLabel: UILabel?
    var recentlyScannedUrls = [String]()

    override func viewDidLayoutSubviews() {
        qrFound = false
        do {
            switch AVCaptureDevice.authorizationStatus(for: .video) {
            case .authorized, .notDetermined: try scanQR() // Will automatically ask permission
            case .denied, .restricted: showCameraDeniedError()
            @unknown default: throw CameraError.unknown
            }
        } catch {
            showAlert(message: "errors.no_camera".localized)
            Logger.shared.warning("Camera not available.", error: error)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        UIView.animate(withDuration: 1.5, delay: 0.5, options: [.curveEaseOut], animations: { self.qrIconImageView.alpha = 0.0 })
    }

    func handleURL(url: URL) throws {
        preconditionFailure("This method must be overridden")
    }

    func metadataOutput(_ output: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        if !metadataObjects.isEmpty, let machineReadableCode = metadataObjects[0] as? AVMetadataMachineReadableCodeObject {
            if machineReadableCode.type == AVMetadataObject.ObjectType.qr {
                if let urlString = machineReadableCode.stringValue, !qrFound {
                    qrFound = true
                    do {
                        guard !self.recentlyScannedUrls.contains(urlString) else {
                            throw CameraError.exists
                        }
                        guard let url = URL(string: urlString) else {
                            throw CameraError.invalid
                        }
                        UIView.animate(withDuration: 0.2, delay: 0.0, options: [.curveLinear], animations: { self.scanCheckmarkImageView.alpha = 1.0 })
                        try self.handleURL(url: url)
                    } catch {
                        switch error {
                        case is URLError:
                            showAlert(message: "errors.undecodable_qr".localized)
                        case SessionError.exists:
                            showAlert(message: "errors.qr_scanned_twice".localized)
                        case SessionError.invalid:
                            Logger.shared.warning("Invalid QR code scanned", error: error)
                            showAlert(message: "errors.undecodable_qr".localized)
                        default:
                            Logger.shared.error("Unhandled pairing error.", error: error)
                            showAlert(message: "errors.generic_error".localized)
                        }
                        self.qrFound = false
                    }
                }
            }
        } else {
            return
        }
    }

    func hideIcon() {
        UIView.animate(withDuration: 1.0, delay: 0.0, options: [.curveEaseOut], animations: { self.scanCheckmarkImageView.alpha = 0.0 })
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
        previewLayer?.frame = videoView.layer.bounds
        videoView.layer.insertSublayer(previewLayer!, at: 0)

        captureSession.startRunning()
    }

    func errorHandler(_ action: UIAlertAction) {
        DispatchQueue.main.async {
            self.hideIcon()
            self.recentlyScannedUrls.removeAll(keepingCapacity: false)
            self.qrFound = false
        }
    }

    // MARK: - Private functions

    private func showCameraDeniedError() {
        let alert = UIAlertController(title: "popups.questions.camera_permission".localized, message: "errors.camera_denied".localized, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "popups.responses.settings".localized, style: .default, handler: { _ in
            if let url = URL.init(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(url, options: [:], completionHandler: nil)
            }
        }))
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
        self.present(alert, animated: true, completion: nil)
    }

}
