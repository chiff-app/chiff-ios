//
//  ManualOTPViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import OneTimePassword
import Base32
import PromiseKit

enum OTPError: Error {
    case invalidSecret
    case invalidParameters
    case empty
}

class ManualOTPViewController: KeynTableViewController, TokenController {

    @IBOutlet weak var keyTextField: UITextField!
    @IBOutlet weak var timeBasedSwitch: UISwitch!
    @IBOutlet weak var saveButton: UIBarButtonItem!

    var account: UserAccount!
    var token: Token?

    override var headers: [String?] {
        return ["accounts.secret".localized, "accounts.mode".localized]
    }
    override var footers: [String?] {
        return ["accounts.secret_description".localized, "accounts.mode_description".localized]
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0
        saveButton.isEnabled = false
        keyTextField.delegate = self
        tableView.separatorColor = UIColor.primaryTransparant
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }

    func add(secret: String, timeBased: Bool) throws {
        guard CharacterSet(charactersIn: secret).isSubset(of: CharacterSet.base32),
            let secretData = MF_Base32Codec.data(fromBase32String: secret),
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
        firstly {
            try AuthorizationGuard.shared.addOTP(token: token!, account: account)
        }.done(on: .main) {
            try self.account.setOtp(token: self.token!)
            self.performSegue(withIdentifier: "UnwindFromManualOTP", sender: self)
        }.catch(on: .main) { error in
            Logger.shared.error("Error adding OTP", error: error)
            self.showAlert(message: "errors.add_otp".localized)
        }
    }

    @IBAction func save(_ sender: UIBarButtonItem) {
        do {
            guard let secret = keyTextField.text, !secret.isEmpty else {
                throw OTPError.empty
            }
            try add(secret: secret.replacingOccurrences(of: " ", with: "").localizedLowercase, timeBased: timeBasedSwitch.isOn)
        } catch {
            switch error {
            case OTPError.invalidSecret, OTPError.empty:
                showAlert(message: "errors.invalid_secret".localized)
            default:
                Logger.shared.error("OTP error occured", error: error)
                showAlert(message: "errors.generic_error".localized)
            }
        }
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

}

extension ManualOTPViewController: UITextFieldDelegate {

    func textField(_ textField: UITextField, shouldChangeCharactersIn range: NSRange, replacementString string: String) -> Bool {
        saveButton.isEnabled = !string.isEmpty
        return CharacterSet(charactersIn: string).isSubset(of: CharacterSet.base32WithSpaces)
    }

}
