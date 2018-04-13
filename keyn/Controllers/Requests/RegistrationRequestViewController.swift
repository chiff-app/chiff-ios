import UIKit

class RegistrationRequestViewController: AccountViewController, UITextFieldDelegate {

    // MARK: Properties

    var notification: PushNotification?
    var session: Session?
    var passwordIsHidden = true
    var newPassword = true
    var passwordValidator: PasswordValidator? = nil
    var site: Site?
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet var requirementLabels: [UILabel]!
    


    override func viewDidLoad() {
        super.viewDidLoad()

        if let site = site {
            websiteNameTextField.text = site.name
            websiteURLTextField.text = site.urls[0]
            passwordValidator = PasswordValidator(ppd: site.ppd)
        }
        
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
        userPasswordTextField.isSecureTextEntry = passwordIsHidden
        showPasswordButton.setImage(UIImage(named: passwordIsHidden ? "eye_logo" : "eye_logo_off"), for: .normal)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Override copy functionality
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

    @IBAction func changePasswordSwitch(_ sender: UISwitch) {
        newPassword = sender.isOn
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
            saveButton.isEnabled = true
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
            requirementLabels[6].text = passwordValidator.validateRequirementGroups(password: password) ? "" : "\u{26A0} There are complicted rules for this PPD. Just try something."
            requirementLabels[7].text = passwordValidator.validateConsecutiveOrderedCharacters(password: password) ? "" : "\u{26A0} The password can't have consecutive characters like abc pr 0123."
        }
    }

    private func createAccount() {
        let type = newPassword ? BrowserMessageType.addAndChange : BrowserMessageType.add
        let password = userPasswordTextField.text
        if let username = userNameTextField.text, let site = site, let notification = notification, let session = session {
            authorizeRequest(site: site, type: type, completion: { [weak self] (succes, error) in
                if (succes) {
                    DispatchQueue.main.async {
                        do {
                            let newAccount = try! Account(username: username, site: site, password: type == BrowserMessageType.addAndChange ? nil : password)
                            self?.account = newAccount
                            try! session.sendCredentials(account: newAccount, browserTab: notification.browserTab, type: type, password: type == BrowserMessageType.addAndChange ? password : nil)

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
                            print("Account could not be saved: \(error)")
                        }
                        self?.performSegue(withIdentifier: "UnwindToRequestViewController", sender: self)
                    }
                } else {
                    print("TODO: Handle touchID errors.")
                }
            })
        }
    }

}
