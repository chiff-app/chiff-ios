import UIKit
import AVFoundation
import LocalAuthentication
import JustLog
import OneTimePassword

class OTPViewController: QRViewController {
    
    var account: Account!
    var accountViewDelegate: canAddOTPCode?
    @IBOutlet weak var instructionLabel: UILabel!
    
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
        try AuthenticationGuard.sharedInstance.addOTP(token: token, account: account, completion: { (error) in
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
                    Logger.shared.error("Error adding OTP", error: error as NSError)
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
     
     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ManualEntry", let destination = segue.destination.contents as? ManualOTPViewController {
            destination.accountViewDelegate = accountViewDelegate
            destination.qrNavCon = navigationController
            destination.account = account
        }
     }
    
    
}
