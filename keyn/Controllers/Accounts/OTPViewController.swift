/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import AVFoundation
import LocalAuthentication
import OneTimePassword

protocol TokenController {
    var token: Token? { get }
}

class OTPViewController: QRViewController, TokenController {
    
    private let OTP_URL_SCHEME = "otpauth"
    
    @IBOutlet weak var instructionLabel: UILabel!

    var account: Account!
    var token: Token?

    override func viewDidLoad() {
        super.viewDidLoad()
        let attributedText = NSMutableAttributedString(string: "accounts.two_fa_instruction".localized, attributes: [
            NSAttributedString.Key.foregroundColor: UIColor.textColor,
            NSAttributedString.Key.font: UIFont.primaryMediumNormal!])
        attributedText.append(NSMutableAttributedString(string: " \(account.site.name)", attributes: [
            NSAttributedString.Key.foregroundColor: UIColor.primary,
            NSAttributedString.Key.font: UIFont.primaryBold!]))
        instructionLabel.attributedText = attributedText
    }
    
    override func handleURL(url: URL) throws {
        guard let scheme = url.scheme, scheme == OTP_URL_SCHEME else {
            showError(message: "errors.session_invalid".localized, handler: errorHandler)
            return
        }
        self.token = Token(url: url)
        guard token != nil else {
            Logger.shared.error("Error creating OTP token")
            showError(message: "errors.token_creation".localized, handler: errorHandler)
            return
        }

        try AuthorizationGuard.addOTP(token: token!, account: account) { (result) in
            DispatchQueue.main.async {
                do {
                    let _ = try result.get()
                    try self.account.setOtp(token: self.token!)
                    self.performSegue(withIdentifier: "UnwindFromOTP", sender: self)
                } catch {
                    Logger.shared.error("Error adding OTP", error: error)
                    self.showError(message: "errors.add_otp".localized, handler: super.errorHandler)
                }
            }
        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ManualEntry", let destination = segue.destination.contents as? ManualOTPViewController {
            destination.account = account
        }
    }
}
