/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import AVFoundation
import LocalAuthentication
import OneTimePassword

class OTPViewController: QRViewController {
    
    private let OTP_URL_SCHEME = "otpauth"
    
    @IBOutlet weak var instructionLabel: UILabel!

    var account: Account!
    var accountViewDelegate: canAddOTPCode?

    override func viewDidLoad() {
        super.viewDidLoad()
        instructionLabel.text = "\("accounts.two_fa_instruction".localized) \(account.site.name)."
    }
    
    override func handleURL(url: URL) throws {
        guard let scheme = url.scheme, scheme == OTP_URL_SCHEME else {
            return
        }
        guard let token = Token(url: url) else {
            return
        }
        try AuthorizationGuard.shared.addOTP(token: token, account: account) { (error) in
            DispatchQueue.main.async {
                do {
                    if let error = error {
                        throw error
                    } else {
                        try self.account.setOtp(token: token)
                        self.add(token: token)
                    }
                } catch {
                    Logger.shared.error("Error adding OTP", error: error)
                }
            }
        }
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
