import UIKit
import MBProgressHUD
import JustLog

class AccountViewController: UITableViewController, UITextFieldDelegate {

    //MARK: Properties
    var editButton: UIBarButtonItem!
    var account: Account?
    var tap: UITapGestureRecognizer!
    
    @IBOutlet weak var websiteNameTextField: UITextField!
    @IBOutlet weak var websiteURLTextField: UITextField!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var userPasswordTextField: UITextField!
    @IBOutlet weak var showPasswordButton: UIButton!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        editButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.edit, target: self, action: #selector(edit))
        navigationItem.rightBarButtonItem = editButton
        
        if let account = account {
            do {
                websiteNameTextField.text = account.site.name
                websiteURLTextField.text = account.site.url
                userNameTextField.text = account.username
                userPasswordTextField.text = try account.password()
                websiteNameTextField.delegate = self
                websiteURLTextField.delegate = self
                userNameTextField.delegate = self
                userPasswordTextField.delegate = self
            } catch {
                // TODO: Present error to user?
                Logger.shared.error("Could not get password.", error: error as NSError)
            }
            navigationItem.title = account.site.name
            navigationItem.largeTitleDisplayMode = .never
        }
        
        tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
    }
    
    // MARK: UITextFieldDelegate
    
    // Hide the keyboard.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        view.addGestureRecognizer(tap)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == websiteNameTextField {
             navigationItem.title = textField.text
        }
        view.removeGestureRecognizer(tap)
    }


    // MARK: Actions
    
    @IBAction func showPassword(_ sender: UIButton) {
        if userPasswordTextField.isEnabled {
            userPasswordTextField.isSecureTextEntry = !userPasswordTextField.isSecureTextEntry
        } else {
            showHiddenPasswordPopup()
        }
    }
    
    @IBAction func deleteAccount(_ sender: UIButton) {
        let alert = UIAlertController(title: "Delete account?", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
            self.performSegue(withIdentifier: "DeleteAccount", sender: self)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 1 && indexPath.row == 1 {
            copyPassword(indexPath)
        }
    }
    
    @objc func edit() {
        let cancelButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.cancel, target: self, action: #selector(cancel))
        let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(update))
        doneButton.style = .done
        
        navigationItem.setLeftBarButton(cancelButton, animated: true)
        navigationItem.setRightBarButton(doneButton, animated: true)
        
        userNameTextField.isEnabled = true
        userPasswordTextField.isEnabled = true
        websiteNameTextField.isEnabled = true
        websiteURLTextField.isEnabled = true
    }
    
    @objc func cancel() {
        endEditing()
        do {
            userPasswordTextField.text = try account?.password()
        } catch {
            Logger.shared.warning("Could not get password", error: error as NSError)
        }
        navigationItem.title = account?.site.name
        userNameTextField.text = account?.username
        websiteNameTextField.text = account?.site.name
        websiteURLTextField.text = account?.site.url
    }
    
    @objc func update() {
        endEditing()
        do {
            var newPassword: String? = nil
            let newUsername = userNameTextField.text != account?.username ? userNameTextField.text : nil
            let newSiteName = websiteNameTextField.text != account?.site.name ? websiteNameTextField.text : nil
            if let oldPassword: String = try account?.password() {
                newPassword = userPasswordTextField.text != oldPassword ? userPasswordTextField.text : nil
            }
            let newUrl = websiteURLTextField.text != account?.site.url ? websiteURLTextField.text : nil
            guard newPassword != nil || newUsername != nil || newSiteName != nil || newUrl != nil else {
                return
            }
            try account?.update(username: newUsername, password: newPassword, siteName: newSiteName, url: newUrl)
            if let accountsTableViewController = navigationController?.viewControllers[0] as? AccountsTableViewController {
                accountsTableViewController.updateAccount(account: account!)
            }
        } catch {
            Logger.shared.warning("Could not change username", error: error as NSError)
            userNameTextField.text = account?.username
            websiteNameTextField.text = account?.site.name
            websiteURLTextField.text = account?.site.url
        }
    }
    
    
    // MARK: Private methods
    
    private func endEditing() {
        userPasswordTextField.isSecureTextEntry = true
        navigationItem.setLeftBarButton(nil, animated: true)
        navigationItem.setRightBarButton(editButton, animated: true)
        userNameTextField.isEnabled = false
        userPasswordTextField.isEnabled = false
        websiteNameTextField.isEnabled = false
        websiteURLTextField.isEnabled = false
    }
    
    private func showHiddenPasswordPopup() {
        do {
            let showPasswordHUD = MBProgressHUD.showAdded(to: self.tableView.superview!, animated: true)
            showPasswordHUD.mode = .text
            showPasswordHUD.bezelView.color = .black
            showPasswordHUD.label.text = try account?.password() ?? "Error fetching password"
            showPasswordHUD.label.textColor = .white
            showPasswordHUD.label.font = UIFont(name: "Courier New", size: 24)
            showPasswordHUD.margin = 10
            showPasswordHUD.label.numberOfLines = 0
            showPasswordHUD.removeFromSuperViewOnHide = true
            showPasswordHUD.addGestureRecognizer(
                UITapGestureRecognizer(
                    target: showPasswordHUD,
                    action: #selector(showPasswordHUD.hide(animated:)))
            )
        } catch {
            Logger.shared.error("Could not get account", error: error as NSError)
        }
    }
    
    private func copyPassword(_ indexPath: IndexPath) {
        guard let passwordCell = tableView.cellForRow(at: indexPath) else {
            return
        }
        
        Logger.shared.info("Password copied to pasteboard.", userInfo: ["code": AnalyticsMessage.passwordCopy.rawValue])
        
        let pasteBoard = UIPasteboard.general
        pasteBoard.string = userPasswordTextField.text
        
        let copiedLabel = UILabel(frame: passwordCell.bounds)
        copiedLabel.text = "Copied"
        copiedLabel.font = copiedLabel.font.withSize(18)
        copiedLabel.textAlignment = .center
        copiedLabel.textColor = .white
        copiedLabel.backgroundColor = UIColor(displayP3Red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        
        passwordCell.addSubview(copiedLabel)
        
        UIView.animate(withDuration: 0.5, delay: 1.0, options: [.curveLinear], animations: {
            copiedLabel.alpha = 0.0
        }) { if $0 { copiedLabel.removeFromSuperview() } }
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "reportSite", let destination = segue.destination.contents as? ReportSiteViewController {
            destination.navigationItem.title = account?.site.name
            destination.account = account
        }
    }

}
