import UIKit
import JustLog

class RegistrationRequestViewController: AccountViewController, UITextFieldDelegate {

    // MARK: Properties

    var notification: PushNotification?
    var session: Session?
    var passwordIsHidden = true
    var passwordValidator: PasswordValidator? = nil
    var site: Site?
    var changePasswordFooterText = "If enabled, Keyn will automatically change the password to a secure password"
    
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet var requirementLabels: [UILabel]!
    @IBOutlet weak var changePasswordCell: UITableViewCell!
    @IBOutlet weak var changePasswordLabel: UILabel!
    @IBOutlet weak var changePasswordSwitch: UISwitch!
    
    
    override func viewDidLoad() {
        super.viewDidLoad()

        guard let site = site else {
            Logger.shared.error("Site was nil when creating new account.")
            fatalError("Site was nil when creating new account.")
        }
        if site.ppd?.service?.passwordChange == nil {
            changePasswordFooterText = "It's not possible to change the password for this site."
            changePasswordCell.isUserInteractionEnabled = false
            changePasswordLabel.isEnabled = false
            changePasswordSwitch.isEnabled = false
            changePasswordSwitch.isOn = false
        }
        
        
        websiteNameTextField.text = site.name
        websiteURLTextField.text = site.url
        if let currentPassword = notification?.currentPassword {
            userPasswordTextField.text = currentPassword
        }
        if let username = notification?.username {
            userNameTextField.text = username
        }
        
        // TODO: Think about what to do with validating passwords in the app. Current PPD implementation is not ideal for validating passwords.
        //passwordValidator = PasswordValidator(ppd: site.ppd)
        
        requirementLabels.sort(by: { (first, second) -> Bool in
            return first.tag < second.tag
        })

        for textField in [websiteNameTextField, websiteURLTextField, userNameTextField, userPasswordTextField] {
            textField?.delegate = self
            textField?.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        }

        updateSaveButtonState()

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }

    @IBAction override func showPassword(_ sender: UIButton) {
        passwordIsHidden = !passwordIsHidden
        
        let wasFirstResponder = userPasswordTextField.isFirstResponder
        if wasFirstResponder { userPasswordTextField.resignFirstResponder() }
        
        userPasswordTextField.isSecureTextEntry = passwordIsHidden
        
        if wasFirstResponder { userPasswordTextField.becomeFirstResponder() }
        
        showPasswordButton.setImage(UIImage(named: passwordIsHidden ? "eye_logo" : "eye_logo_off"), for: .normal)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Override copy functionality
    }
    
    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if section == 1 {
            return changePasswordFooterText
        }
        return nil
    }

    
    // MARK: UITextFieldDelegate

    // Hide the keyboard.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        updateSaveButtonState()
    }

    @objc func textFieldDidChange(textField: UITextField){
        updateSaveButtonState()
    }

    // MARK: Actions

    func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status and drop into background
        view.endEditing(true)
    }

    @IBAction func saveAccount(_ sender: UIBarButtonItem) {
        createAccount()
    }

    // MARK: Private Methods

    // Disable the Save button if one the text fields is empty.
    private func updateSaveButtonState() {
        let username = userNameTextField.text ?? ""
        let password = userPasswordTextField.text ?? ""
        
        updatePasswordRequirements(password: password)

        if (username.isEmpty || password.isEmpty || !isValidPassword(password: password)) {
            saveButton.isEnabled = false
        } else {
            if let notification = notification, notification.requestType == .add, let accounts = try? Account.get(siteID: notification.siteID) {
                let usernameExists = accounts.contains { (account) -> Bool in
                    account.username == username
                }
                if usernameExists {
                    saveButton.isEnabled = false
                } else {
                    saveButton.isEnabled = true
                }
            } else {
                saveButton.isEnabled = true
            }
        }
    }
    
    private func isValidPassword(password: String) -> Bool {
        if password.isEmpty { return false }
        if let passwordValidator = passwordValidator {
            return passwordValidator.validate(password: password)
        }
        return true
    }
    
    private func updatePasswordRequirements(password: String) {
        if let passwordValidator = passwordValidator {
            requirementLabels[0].text = passwordValidator.validateMinLength(password: password) ? "" : "\u{26A0} The password needs to be at least \(site?.ppd?.properties?.minLength ?? PasswordValidator.MIN_PASSWORD_LENGTH_BOUND) characters."
            requirementLabels[1].text = passwordValidator.validateMaxLength(password: password) ? "" : "\u{26A0} The password can have no more than \(site?.ppd?.properties?.maxLength ?? PasswordValidator.MAX_PASSWORD_LENGTH_BOUND) characters."
            requirementLabels[2].text = passwordValidator.validateCharacters(password: password) ? "" : "\u{26A0} The password has invalid characters."
            requirementLabels[3].text = passwordValidator.validateCharacterSet(password: password) ? "" : "\u{26A0} There are specific constraints for this site."
            requirementLabels[4].text = passwordValidator.validateConsecutiveCharacters(password: password) ? "" : "\u{26A0} The password can't have more than n consecutive characters like aaa or ***."
            requirementLabels[5].text = passwordValidator.validatePositionRestrictions(password: password) ? "" : "\u{26A0} The password needs to start with a mysterious character."
            requirementLabels[6].text = passwordValidator.validateRequirementGroups(password: password) ? "" : "\u{26A0} There are complicted rules for this site. Just try something."
            requirementLabels[7].text = passwordValidator.validateConsecutiveOrderedCharacters(password: password) ? "" : "\u{26A0} The password can't have consecutive characters like abc or 0123."
        }
    }

    private func createAccount() {
        
        let newPassword = changePasswordSwitch.isOn
        var type: BrowserMessageType
        switch notification!.requestType {
        case .login, .add:
            type = newPassword ? BrowserMessageType.addAndChange : BrowserMessageType.add
        case .change:
            type = newPassword ? BrowserMessageType.change : BrowserMessageType.confirm
        default:
            type = BrowserMessageType.confirm
        }
        
        let password = userPasswordTextField.text
        if let username = userNameTextField.text, let site = site, let notification = notification, let session = session {
            UserDefaults.standard.set(username, forKey: "username")
            AuthenticationGuard.sharedInstance.authorizeRequest(siteName: notification.siteName, accountID: nil, type: type, completion: { [weak self] (succes, error) in
                if (succes) {
                    DispatchQueue.main.async {
                        do {
                            let newAccount = try Account(username: username, site: site, password: password)
                            self?.account = newAccount
                            try session.sendCredentials(account: newAccount, browserTab: notification.browserTab, type: type)

                            // TODO: Make this better. Works but ugly
                            if let appDelegate = UIApplication.shared.delegate as? AppDelegate, let rootViewController = appDelegate.window!.rootViewController as? RootViewController, let accountsNavigationController = rootViewController.viewControllers?[0] as? UINavigationController {
                                for viewController in accountsNavigationController.viewControllers {
                                    if let accountsTableViewController = viewController as? AccountsTableViewController {
                                        if accountsTableViewController.isViewLoaded {
                                            accountsTableViewController.addAccount(account: newAccount)
                                        }
                                    }
                                }
                            }
                        } catch {
                            // TODO: Handle errors in UX
                            Logger.shared.error("Account could not be saved.", error: error as NSError)
                        }
                        self?.performSegue(withIdentifier: "UnwindToRequestViewController", sender: self)
                    }
                } else {
                    Logger.shared.debug("TODO: Handle touchID errors.")
                }
            })
        }
    }

}
