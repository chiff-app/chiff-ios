/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import AVFoundation
import LocalAuthentication
import OneTimePassword
import PromiseKit

protocol TokenController {
    var token: Token? { get }
}

class OTPViewController: QRViewController, TokenController {

    private let otpURLScheme = "otpauth"

    @IBOutlet weak var instructionLabel: UILabel!

    var account: UserAccount!
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
        guard let scheme = url.scheme, scheme == otpURLScheme else {
            showAlert(message: "errors.session_invalid".localized, handler: errorHandler)
            return
        }
        self.token = Token(url: url)
        guard token != nil else {
            Logger.shared.error("Error creating OTP token")
            showAlert(message: "errors.token_creation".localized, handler: errorHandler)
            return
        }
        firstly {
            try AuthorizationGuard.shared.addOTP(token: token!, account: account)
        }.done(on: .main) {
            try self.account.setOtp(token: self.token!)
            self.performSegue(withIdentifier: "UnwindFromOTP", sender: self)
        }.catch(on: .main) { error in
            Logger.shared.error("Error adding OTP", error: error)
            self.showAlert(message: "errors.add_otp".localized, handler: super.errorHandler)
        }
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ManualEntry", let destination = segue.destination.contents as? ManualOTPViewController {
            destination.account = account
        }
    }
}
