import UIKit

class NewAccountViewController: AccountViewController, UITextFieldDelegate {
    
    // MARK: Properties
    
    var passwordIsHidden = true
    @IBOutlet weak var saveButton: UIBarButtonItem!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        websiteNameTextField.delegate = self
        websiteURLTextField.delegate = self
        userNameTextField.delegate = self
        
        updateSaveButtonState()

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    @IBAction override func showPassword(_ sender: UIButton) {
        if passwordIsHidden {
            passwordIsHidden = false
            userPasswordTextField.isSecureTextEntry = false
            showPasswordButton.setImage(UIImage(named: "eye_logo"), for: UIControlState.normal)
        } else {
            passwordIsHidden = true
            userPasswordTextField.isSecureTextEntry = true
            showPasswordButton.setImage(UIImage(named: "eye_logo_off"), for: UIControlState.normal)
        }
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
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        // Disable the Save button while editing.
        saveButton.isEnabled = false
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        updateSaveButtonState()
    }
    
    
    // MARK: Actions
    
    func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status and drop into background
        view.endEditing(true)
    }
    
    
    // MARK: Private Methods
    
    // Disable the Save button if one the text fields is empty.
    private func updateSaveButtonState() {
        let websiteName = websiteNameTextField.text ?? ""
        let websiteURL = websiteURLTextField.text ?? ""
        let userName = userNameTextField.text ?? ""

        if (websiteName.isEmpty || websiteURL.isEmpty || userName.isEmpty) {
            saveButton.isEnabled = false
        } else {
            saveButton.isEnabled = true
            showPasswordPreview()
        }
    }

    private func showPasswordPreview() {
        if let websiteName = websiteNameTextField.text,
            let websiteURL = websiteURLTextField.text,
            let username = userNameTextField.text {

            let id = String((websiteName + websiteURL).hashValue)
            let site = Site(name: websiteName, id: id, urls: [websiteURL])
            let restrictions = PasswordRestrictions(length: 24, characters: [.lower, .numbers, .upper, .symbols])
            do {

                // This is only a preview, password will be generated when account is created
                let password = try Crypto.generatePassword(username: username, passwordIndex: 0, siteID: site.id, restrictions: restrictions)
                userPasswordTextField.text = password
            } catch {
                print(error)
            }
        }
    }
    
    private func createAccount() {
        if let websiteName = websiteNameTextField.text,
            let websiteURL = websiteURLTextField.text,
            let username = userNameTextField.text {

            // TODO: Where to get site(ID) from if account is manually added?
            //       How to determine password requirements? > Maybe don't allow creation in app.
            print("TODO: Site info + id should be fetched from somewhere instead of generated here..")

            let id = String((websiteName + websiteURL).hashValue)
            let site = Site(name: websiteName, id: id, urls: [websiteURL])
            let restrictions = PasswordRestrictions(length: 24, characters: [.lower, .numbers, .upper, .symbols])
            do {
                account = try Account(username: username, site: site, restrictions: restrictions)
            } catch {
                // TODO: Handle errors in UX
                print(error)
            }


        }
    }
    
    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if let button = sender as? UIBarButtonItem, button === saveButton {
            print("TODO: This should save the account to database. Now only password is saved to keychain")
            createAccount()
        }
    }

}
