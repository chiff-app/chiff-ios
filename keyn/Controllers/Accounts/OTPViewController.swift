import UIKit
import AVFoundation
import LocalAuthentication
import JustLog
import OneTimePassword

class OTPViewController: QRViewController {
    
    var account: Account!
    
    override func handleURL(url: URL) throws {
        guard let scheme = url.scheme, scheme == "otpauth" else {
            return
        }
        guard let token = Token(url: url) else {
            return
        }
        try AuthenticationGuard.sharedInstance.addOTP(token: token, account: account, completion: { [weak self] (error) in
            DispatchQueue.main.async {
                do {
                    if self?.account.hasOtp ?? false {
                        try self?.account.updateOtp(token: token)
                    } else {
                        try self?.account.addOtp(token: token)
                    }
                } catch {
                    Logger.shared.error("Error adding OTP", error: error as NSError)
                }
            }
        })
        
    }
    
}
