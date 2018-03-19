import UIKit

class NewAccountViewController: AccountViewController, UITextFieldDelegate {
    
    // MARK: Properties
    
    var passwordIsHidden = true
    var customPassword = false
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        for textField in [websiteNameTextField, websiteURLTextField, userNameTextField, userPasswordTextField] {
            textField?.delegate = self
            textField?.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        }
        
        updateSaveButtonState()

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
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
    
    @IBAction func customPasswordSwitch(_ sender: UISwitch) {
        let passwordRowIndex = IndexPath(row: 3, section: 0)
        if sender.isOn {
            customPassword = true
            userPasswordTextField.isEnabled = true
            userPasswordTextField.text = ""
            tableView.reloadRows(at: [passwordRowIndex], with: .bottom)
            tableView.reloadSections([1], with: .fade)
            tableView.reloadData()
        } else {
            customPassword = false
            tableView.reloadRows(at: [passwordRowIndex], with: .top)
            tableView.reloadSections([1], with: .fade)
            tableView.reloadData()
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

        if (websiteName.isEmpty || websiteURL.isEmpty || userName.isEmpty || (customPassword && password.isEmpty)) {
            saveButton.isEnabled = false
        } else {
            saveButton.isEnabled = true
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
            let restrictions = PasswordRestrictions(length: 24, characters: [.lower, .numbers, .upper, .symbols])
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
