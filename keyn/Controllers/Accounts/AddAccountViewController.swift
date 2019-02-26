/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

/*
 * TODO:
 * - Add breached accounts information
 * - Add MFA QR-code scan
 */
class AddAccountViewController: UITableViewController, UITextFieldDelegate {

    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var requirementsView: UIView!
    @IBOutlet var requirementLabels: [UILabel]!
    @IBOutlet weak var requirementLabelsStackView: UIStackView!

    @IBOutlet weak var siteNameField: UITextField!
    @IBOutlet weak var siteURLField: UITextField!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var showPasswordButton: UIButton!

    private let ppd: PPD? = nil
    private var passwordValidator: PasswordValidator? = nil
    private var passwordIsHidden = true
    var account: Account?

    override func viewDidLoad() {
        super.viewDidLoad()

        for textField in [siteNameField, siteURLField, usernameField, passwordField] {
            textField?.delegate = self
            textField?.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        }

        requirementLabels.sort(by: { (first, second) -> Bool in
            return first.tag < second.tag
        })
        
        updateSaveButtonState()
    }

    @IBAction func showPassword(_ sender: UIButton) {
        passwordIsHidden = !passwordIsHidden
        passwordField.isSecureTextEntry = passwordIsHidden
        showPasswordButton.setImage(UIImage(named: passwordIsHidden ? "eye_logo" : "eye_logo_off"), for: .normal)
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    
    // MARK: UITextFieldDelegate

    @objc func textFieldDidChange(textField: UITextField){
        updateSaveButtonState()
    }
    
    // MARK: - Actions

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Override copy functionality
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let button = sender as? UIBarButtonItem, button === saveButton {
            createAccount()
        }
    }
    
    // MARK: - Private

    private func updateSaveButtonState() {
        let siteName = siteNameField.text ?? ""
        let siteURL = siteURLField.text ?? ""
        let username = usernameField.text ?? ""
        let password = passwordField.text ?? ""

        updatePasswordRequirements(password: password)

        if (siteName.isEmpty || siteURL.isEmpty || username.isEmpty || !isValidPassword(password: password)) {
            saveButton.isEnabled = false
        } else {
            saveButton.isEnabled = true
        }
    }

    private func isValidPassword(password: String) -> Bool {
        if password.isEmpty {
            return false
        }
        
        if let passwordValidator = passwordValidator {
            return passwordValidator.validate(password: password)
        } else {
            return true
        }
    }

    // TODO: Fetch correct requirements from PPD and present to user.
    private func updatePasswordRequirements(password: String) {
        if let passwordValidator = passwordValidator {
            requirementLabels[0].text = passwordValidator.validateMinLength(password: password) ? "" : "\u{26A0} The password needs to be at least \(8) characters."
            requirementLabels[1].text = passwordValidator.validateMaxLength(password: password) ? "" : "\u{26A0} The password can have no more than \(50) characters."
            requirementLabels[2].text = passwordValidator.validateCharacters(password: password) ? "" : "\u{26A0} The password has invalid characters."
            requirementLabels[3].text = passwordValidator.validateCharacterSet(password: password) ? "" : "\u{26A0} CharacterSet constraint"
            requirementLabels[4].text = passwordValidator.validateConsecutiveCharacters(password: password) ? "" : "\u{26A0} The password can't have more than n consecutive characters like aaa or ***."
            requirementLabels[5].text = passwordValidator.validatePositionRestrictions(password: password) ? "" : "\u{26A0} The password needs to start with a mysterious character."
            requirementLabels[6].text = passwordValidator.validateRequirementGroups(password: password) ? "" : "\u{26A0} There are complicted rules for this PPD. Just try something."
            requirementLabels[7].text = passwordValidator.validateConsecutiveOrderedCharacters(password: password) ? "" : "\u{26A0} The password can't have consecutive characters like abc pr 0123."
        }
    }
    
    private func createAccount() {
        if let websiteName = siteNameField.text, let websiteURL = siteURLField.text, let username = usernameField.text, let password = passwordField.text {

            // TODO: Where to get site(ID) from if account is manually added?
            //       How to determine password requirements? > Maybe don't allow creation in app.
            print("TODO: Site info + id should be fetched from somewhere instead of generated here..")

            let url = URL(string: websiteURL)
            let id = url!.absoluteString.sha256 // TODO, fix
            let site = Site(name: websiteName, id: id, url: websiteURL, ppd: nil)

            do {
                self.account = try Account(username: username, site: site, password: password) // saves
            } catch {
                // TODO: Handle errors in UX
                print("Account could not be saved: \(error)")
            }
        }
    }

}