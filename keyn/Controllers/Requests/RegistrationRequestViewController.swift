import UIKit

class RegistrationRequestViewController: AccountViewController, UITextFieldDelegate {

    // MARK: Properties

    var notification: PushNotification?
    var session: Session?
    var passwordIsHidden = true
    var newPassword = false
    var passwordValidator: PasswordValidator? = nil
    var site: Site?
    @IBOutlet weak var saveButton: UIBarButtonItem!



    override func viewDidLoad() {
        super.viewDidLoad()

        if let site = site {
            websiteNameTextField.text = site.name
            websiteURLTextField.text = site.urls[0]
        }

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

        if (username.isEmpty || password.isEmpty) {
            saveButton.isEnabled = false
        } else {
            saveButton.isEnabled = true
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
                            let newAccount = try Account(username: username, site: site, password: type == BrowserMessageType.addAndChange ? nil : password)
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

    // MARK: - Navigation

//    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
//        super.prepare(for: segue, sender: sender)
//        if let button = sender as? UIBarButtonItem, button === saveButton {
//            createAccount()
//        }
//    }

}

