//
//  QRViewController.swift
//  athena
//
//  Created by Bas Doorn on 04/11/2017.
//  Copyright © 2017 athena. All rights reserved.
//

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

    enum CameraError: Error {
        case noCamera
        case videoInputInitFailed
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
           try scanQR()
        } catch {
            print("TODO: find out which error can be thrown")
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
                if let json = machineReadableCode.stringValue, !qrFound {
                    decodeSessionData(json)
                }
            }
        } else { return }
    }
    
    
    // MARK: Private Methods
    
    private func decodeSessionData(_ json: String) {
        let decoder = JSONDecoder()
        if let jsonData = json.data(using: .utf8),
            let session = try? decoder.decode(Session.self, from: jsonData) {
            qrFound = true
            delegate?.addSession(session: session)
            if isFirstSession {
                _ = navigationController?.popViewController(animated: false)
            } else {
                dismiss(animated: true, completion: nil)
            }
        } else {
            // TODO: Notify user that QR code is invalid.
            print("QR code could not be decoded.")
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
