/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

#warning("TODO: Add MFA QR-code scan")
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
    var account: UserAccount?

    override func viewDidLoad() {
        super.viewDidLoad()

        for textField in [siteNameField, siteURLField, usernameField, passwordField] {
            textField?.delegate = self
            textField?.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        }

        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0

        tableView.separatorColor = UIColor.primaryTransparant

        requirementLabels.sort(by: { $0.tag < $1.tag })
        
        updateSaveButtonState()
        Logger.shared.analytics(.addAccountOpened)
        reEnableBarButtonFont()
    }

    @IBAction func showPassword(_ sender: UIButton) {
        passwordIsHidden = !passwordIsHidden
        passwordField.isSecureTextEntry = passwordIsHidden
        showPasswordButton.setImage(UIImage(named: passwordIsHidden ? "eye_logo" : "eye_logo_off"), for: .normal)
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
    

    // MARK: - UITableView

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch section {
        case 0:
            return "accounts.website_details".localized.capitalizedFirstLetter
        case 1:
            return "accounts.user_details".localized.capitalizedFirstLetter
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        switch section {
        case 0:
            return "accounts.url_warning".localized.capitalizedFirstLetter
        default:
            return nil
        }
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard section < 2 else {
            return
        }

        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = UIColor.primaryHalfOpacity
        header.textLabel?.font = UIFont.primaryBold
        header.textLabel?.textAlignment = NSTextAlignment.left
        header.textLabel?.frame = header.frame
        header.textLabel?.text = section == 0 ? "accounts.website_details".localized.capitalizedFirstLetter : "accounts.user_details".localized.capitalizedFirstLetter
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard section < 2 else {
            return
        }
        let footer = view as! UITableViewHeaderFooterView
        footer.textLabel?.textColor = UIColor.textColorHalfOpacity
        footer.textLabel?.font = UIFont.primaryMediumSmall
        footer.textLabel?.textAlignment = NSTextAlignment.left
        footer.textLabel?.frame = footer.frame
        footer.textLabel?.text = "accounts.url_warning".localized.capitalizedFirstLetter
    }
    
    // MARK: UITextFieldDelegate

    @objc func textFieldDidChange(textField: UITextField){
        updateSaveButtonState()
    }
    
    // MARK: - Actions

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // IMPORTANT: Override copy functionality
    }

    @IBAction func saveAccount(_ sender: Any) {
        createAccount()
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

    #warning("TODO: Fetch correct requirements from PPD and present to user.")
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

    #warning("TODO: How do we save accounts when there is no Site object? This happens when a user adds an account manually.")
    private func createAccount() {
        if let websiteName = siteNameField.text, let websiteURL = siteURLField.text, let username = usernameField.text, let password = passwordField.text {
            let url = URL(string: websiteURL)
            let id = url!.absoluteString.lowercased().sha256
            let site = Site(name: websiteName, id: id, url: websiteURL, ppd: nil)
            do {
                self.account = try UserAccount(username: username, sites: [site], password: password, rpId: nil, algorithms: nil, context: nil)
                self.performSegue(withIdentifier: "UnwindToAccountOverview", sender: self)
                Logger.shared.analytics(.accountAddedLocal)
            } catch {
                showAlert(message: "\("errors.save_account".localized): \(error)")
                Logger.shared.error("Account could not be saved", error: error)
            }

        }
    }

}
