/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import AVFoundation
import LocalAuthentication
import OneTimePassword

class OTPViewController: QRViewController {    
    @IBOutlet weak var instructionLabel: UILabel!

    var account: Account!
    var accountViewDelegate: canAddOTPCode?

    override func viewDidLoad() {
        super.viewDidLoad()
        instructionLabel.text = "Scan the 2FA-code for \(account.site.name)."
    }
    
    override func handleURL(url: URL) throws {
        guard let scheme = url.scheme, scheme == "otpauth" else {
            return
        }
        guard let token = Token(url: url) else {
            return
        }
        try AuthenticationGuard.shared.addOTP(token: token, account: account, completion: { (error) in
            DispatchQueue.main.async {
                guard error == nil else {
                    Logger.shared.error("Error authorizing OTP", error: error! as NSError)
                    return
                }
                do {
                    if self.account.hasOtp() {
                        try self.account.updateOtp(token: token)
                    } else {
                        try self.account.addOtp(token: token)
                    }
                    self.add(token: token)
                } catch {
                    Logger.shared.error("Error adding OTP", error: error)
                }
            }
        })
    }
    
    func add(token: Token) {
        if let delegate = accountViewDelegate {
            delegate.addOTPCode(token: token)
        }
        _ = navigationController?.popViewController(animated: true)
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ManualEntry", let destination = segue.destination.contents as? ManualOTPViewController {
            destination.accountViewDelegate = accountViewDelegate
            destination.qrNavCon = navigationController
            destination.account = account
        }
    }
}
