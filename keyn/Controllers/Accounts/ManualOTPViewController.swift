/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import OneTimePassword
import Base32

enum OTPError: KeynError {
    case invalidSecret
    case invalidParameters
    case empty
}

class ManualOTPViewController: UITableViewController, TokenController {

    @IBOutlet weak var keyTextField: UITextField!
    @IBOutlet weak var timeBasedSwitch: UISwitch!
    @IBOutlet weak var errorLabel: UILabel!

    var account: UserAccount!
    var token: Token?

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0

        tableView.separatorColor = UIColor.primaryTransparant
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }

    // MARK: - UITableView

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard section < 2 else {
            return
        }

        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = UIColor.primaryHalfOpacity
        header.textLabel?.font = UIFont.primaryBold
        header.textLabel?.textAlignment = NSTextAlignment.left
        header.textLabel?.frame = header.frame
        header.textLabel?.text = section == 0 ? "accounts.secret".localized : "accounts.mode".localized
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        let footer = view as! UITableViewHeaderFooterView
        footer.textLabel?.textColor = UIColor.textColorHalfOpacity
        footer.textLabel?.font = UIFont.primaryMediumSmall
        footer.textLabel?.textAlignment = NSTextAlignment.left
        footer.textLabel?.frame = footer.frame
        footer.textLabel?.text = section == 0 ? "accounts.secret_description".localized : "accounts.mode_description".localized
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
        self.token = Token(generator: generator)

        try AuthorizationGuard.addOTP(token: token!, account: account) { (result) in
            DispatchQueue.main.async {
                do {
                    let _ = try result.get()
                    try self.account.setOtp(token: self.token!)
                    self.performSegue(withIdentifier: "UnwindFromManualOTP", sender: self)
                } catch {
                    Logger.shared.error("Error adding OTP", error: error)
                    self.showAlert(message: "errors.add_otp".localized)
                }
            }
        }
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
                Logger.shared.error("OTP error occured", error: error)
            }
        }
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

}
