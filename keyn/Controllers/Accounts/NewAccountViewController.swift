import UIKit

class NewAccountViewController: AccountViewController, UITextFieldDelegate {
    
    // MARK: Properties
    
    var passwordIsHidden = true
    var customPassword = false
    let ppd: PPD? = nil
    var passwordValidator: PasswordValidator? = nil
    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var requirementsView: UIView!
    @IBOutlet var requirementLabels: [UILabel]!
    @IBOutlet weak var requirementLabelsStackView: UIStackView!


    override func viewDidLoad() {
        super.viewDidLoad()

        for textField in [websiteNameTextField, websiteURLTextField, userNameTextField, userPasswordTextField] {
            textField?.delegate = self
            textField?.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        }

        requirementLabels.sort(by: { (first, second) -> Bool in
            return first.tag < second.tag
        })

        // TODO: get PPD?
        
        updateSaveButtonState()

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }


    @IBAction override func showPassword(_ sender: UIButton) {
        passwordIsHidden = !passwordIsHidden
        userPasswordTextField.isSecureTextEntry = passwordIsHidden
        showPasswordButton.setImage(UIImage(named: passwordIsHidden ? "eye_logo" : "eye_logo_off"), for: .normal)
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
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
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if (indexPath.section == 0 && indexPath.row == 3) {
            return customPassword ? 44 : 0
        }
        return 44
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // Override copy functionality
    }
    
    @IBAction func customPasswordSwitch(_ sender: UISwitch) {
        let passwordRowIndex = IndexPath(row: 3, section: 0)
        let usernameRowIndex = IndexPath(row: 2, section: 0)
        if sender.isOn {
            customPassword = true
            userPasswordTextField.isEnabled = true
            userPasswordTextField.text = ""
            if passwordValidator == nil {
                passwordValidator = PasswordValidator(ppd: ppd)
            }
            requirementsView.isHidden = false
            updatePasswordRequirements(password: userPasswordTextField.text ?? "")
            tableView.reloadRows(at: [passwordRowIndex], with: .bottom)
            tableView.reloadSections([1], with: .fade)
            tableView.reloadData()
            tableView.cellForRow(at: usernameRowIndex)?.separatorInset = UIEdgeInsets(top: 0, left: 15, bottom: 0, right: 0)
        } else {
            customPassword = false
            tableView.cellForRow(at: usernameRowIndex)?.separatorInset = UIEdgeInsets(top: 0, left: 0, bottom: 0, right: 0)
            tableView.reloadRows(at: [passwordRowIndex], with: .top)
            tableView.reloadSections([1], with: .fade)
            tableView.reloadData()
            requirementsView.isHidden = true
            userPasswordTextField.isEnabled = false
            updateSaveButtonState()
        }
    }
    
    
    // MARK: Private Methods

    
    // Disable the Save button if one the text fields is empty.
    private func updateSaveButtonState() {
        let websiteName = websiteNameTextField.text ?? ""
        let websiteURL = websiteURLTextField.text ?? ""
        let userName = userNameTextField.text ?? ""
        let password = userPasswordTextField.text ?? ""

        updatePasswordRequirements(password: password)

        if (websiteName.isEmpty || websiteURL.isEmpty || userName.isEmpty || !isValidPassword(password: password)) {
            saveButton.isEnabled = false
        } else {
            saveButton.isEnabled = true
        }
    }

    private func isValidPassword(password: String) -> Bool {
        if customPassword {
            if password.isEmpty { return false }
            if let passwordValidator = passwordValidator {
                return passwordValidator.validate(password: password)
            }
        }
        return true
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
        if let websiteName = websiteNameTextField.text,
            let websiteURL = websiteURLTextField.text,
            let username = userNameTextField.text {

            // TODO: Where to get site(ID) from if account is manually added?
            //       How to determine password requirements? > Maybe don't allow creation in app.
            print("TODO: Site info + id should be fetched from somewhere instead of generated here..")

            let id = String(websiteName + websiteURL).hashValue
            let site = Site(name: websiteName, id: id, urls: [websiteURL], ppd: nil)

            do {
                let newAccount = try Account(username: username, site: site, password: customPassword ? userPasswordTextField.text : nil)
                account = newAccount
            } catch {
                // TODO: Handle errors in UX
                print("Account could not be saved: \(error)")
            }


        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let button = sender as? UIBarButtonItem, button === saveButton {
            createAccount()
        }
    }

}
