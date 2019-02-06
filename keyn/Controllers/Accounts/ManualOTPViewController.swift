/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import OneTimePassword
import Base32
import JustLog

enum OTPError: Error {
    case invalidSecret
    case invalidParameters
    case empty
}

class ManualOTPViewController: UITableViewController {
    @IBOutlet weak var keyTextField: UITextField!
    @IBOutlet weak var timeBasedSwitch: UISwitch!
    @IBOutlet weak var errorLabel: UILabel!
    var qrNavCon: UINavigationController?
    var accountViewDelegate: canAddOTPCode?
    var account: Account!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        navigationItem.title = account.site.name
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }
    
    func add(secret: String, timeBased: Bool) throws {
        guard let secretData = MF_Base32Codec.data(fromBase32String: secret),
            !secretData.isEmpty else {
                throw OTPError.invalidSecret
        }
        guard let generator = Generator(
            factor: timeBased ? .timer(period: 30) : .counter(0),
            secret: secretData,
            algorithm: .sha1,
            digits: 6) else {
            throw OTPError.invalidSecret
        }
        let token = Token(generator: generator)
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
                    if let delegate = self.accountViewDelegate {
                        delegate.addOTPCode(token: token)
                    }
                    _ = self.qrNavCon?.popViewController(animated: true)
                    self.dismiss(animated: true, completion: nil)
                } catch {
                    Logger.shared.error("Error adding OTP", error: error as NSError)
                }
            }
        })

    }

    @IBAction func save(_ sender: UIBarButtonItem) {
        do {
            guard let secret = keyTextField.text, secret != "" else {
                throw OTPError.empty
            }
            try add(secret: secret.replacingOccurrences(of: " ", with: ""), timeBased: timeBasedSwitch.isOn)
        } catch {
            switch error {
            case OTPError.invalidSecret:
                errorLabel.text = "The secret should consist of characters A-Z and numbers 2-7."
            case OTPError.empty:
                errorLabel.text = "The secret can't be empty."
            default:
                Logger.shared.error("OTP error occured", error: error as NSError)
            }
        }
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}
