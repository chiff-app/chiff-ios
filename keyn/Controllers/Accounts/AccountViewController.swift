/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import MBProgressHUD
import OneTimePassword
import QuartzCore

class AccountViewController: UITableViewController, UITextFieldDelegate, SitesDelegate {

    @IBOutlet weak var websiteNameTextField: UITextField!
    @IBOutlet weak var websiteURLTextField: UITextField!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var userPasswordTextField: UITextField!
    @IBOutlet weak var userCodeTextField: UITextField!
    @IBOutlet weak var showPasswordButton: UIButton!
    @IBOutlet weak var userCodeCell: UITableViewCell!
    @IBOutlet weak var totpLoader: UIView!
    @IBOutlet weak var totpLoaderWidthConstraint: NSLayoutConstraint!
    @IBOutlet weak var enabledSwitch: UISwitch!
    @IBOutlet weak var bottomSpacer: UIView!

    var editButton: UIBarButtonItem!
    var account: Account!
    var tap: UITapGestureRecognizer!
    var qrEnabled: Bool = true
    var editingMode: Bool = false
    var otpCodeTimer: Timer?
    var token: Token?
    var loadingCircle: FilledCircle?
    var showAccountEnableButton: Bool = false
    var canEnableAccount: Bool = true

    var password: String? {
        return try? account.password()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        editButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.edit, target: self, action: #selector(edit))
        navigationItem.rightBarButtonItem = editButton

        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0

        tableView.separatorColor = UIColor.primaryTransparant
        bottomSpacer.frame = CGRect(x: bottomSpacer.frame.minX, y: bottomSpacer.frame.minY, width: bottomSpacer.frame.width, height: showAccountEnableButton ? 40.0 : 0)
        loadAccountData()

        tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        (tabBarController as? RootViewController)?.showGradient(true)
    }

    private func loadAccountData() {
        do {
            websiteNameTextField.text = account.site.name
            websiteURLTextField.text = account.site.url
            userNameTextField.text = account.username
            userPasswordTextField.text = password ?? "22characterplaceholder"
            token = try account.oneTimePasswordToken()
            enabledSwitch.isOn = account.enabled
            enabledSwitch.isEnabled = account.enabled || canEnableAccount
            updateOTPUI()
            websiteNameTextField.delegate = self
            websiteURLTextField.delegate = self
            userNameTextField.delegate = self
            userPasswordTextField.delegate = self
        } catch {
            showError(message: "errors.otp_fetch".localized)
            Logger.shared.error("AccountViewController could not get an OTP token.", error: error)
        }
    }

    // MARK: - UITableView

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if (indexPath.section == 1 && indexPath.row == 2 && token == nil) || (indexPath.section == 0 && indexPath.row == 1 && account.sites.count > 1) {
            cell.accessoryView = UIImageView(image: UIImage(named: "chevron_right"))
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return editingMode || showAccountEnableButton ? 3 : 2
    }

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
        case 1:
            return "accounts.2fa_description".localized.capitalizedFirstLetter
        case 2:
            return showAccountEnableButton ? "accounts.footer_account_enabled".localized.capitalizedFirstLetter : nil
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
        guard section < 2 || showAccountEnableButton else {
            return
        }
        let footer = view as! UITableViewHeaderFooterView
        footer.textLabel?.textColor = UIColor.textColorHalfOpacity
        footer.textLabel?.font = UIFont.primaryMediumSmall
        footer.textLabel?.textAlignment = NSTextAlignment.left
        footer.textLabel?.frame = footer.frame
        switch section {
        case 0:
            footer.textLabel?.text = "accounts.url_warning".localized.capitalizedFirstLetter
            footer.textLabel?.isHidden = !tableView.isEditing
        case 1:
            footer.textLabel?.isHidden = false
            footer.textLabel?.text = "accounts.2fa_description".localized.capitalizedFirstLetter
            footer.textLabel?.numberOfLines = 3
        case 2:
            footer.textLabel?.isHidden = false
            footer.textLabel?.text = "accounts.footer_account_enabled".localized.capitalizedFirstLetter
        default:
            fatalError("An extra section appeared!")
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1 && indexPath.row == 2 && token != nil && tableView.isEditing
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        try? self.account.deleteOtp()
        self.token = nil
        DispatchQueue.main.async {
            self.updateOTPUI()
        }
        tableView.cellForRow(at: indexPath)?.setEditing(false, animated: true)

    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 2 && showAccountEnableButton && indexPath.row > 0 {
            return editingMode ? tableView.rowHeight : 0
        } else if indexPath.section == 2 && !showAccountEnableButton && indexPath.row == 0 {
            return 0.5 // So we still have a border
        }
        return tableView.rowHeight
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            if indexPath.row == 1 && account.sites.count > 1 {
                performSegue(withIdentifier: "ShowSiteOverview", sender: self)
            }
        } else if indexPath.section == 1 {
            if indexPath.row == 1 || (indexPath.row == 2 && !qrEnabled) {
                copyToPasteboard(indexPath)
            } else if indexPath.row == 2 && qrEnabled {
                performSegue(withIdentifier: "showQR", sender: self)
            }
        }
    }
    
    // MARK: - UITextFieldDelegate
    
    // Hide the keyboard.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        view.addGestureRecognizer(tap)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        view.removeGestureRecognizer(tap)
    }

    // MARK: - Actions

    @IBAction func enableSwitchChanged(_ sender: UISwitch) {
        do {
            try account.update(username: nil, password: nil, siteName: nil, url: nil, askToLogin: nil, askToChange: nil, enabled: sender.isOn)
            NotificationCenter.default.post(name: .accountUpdated, object: self, userInfo: ["account": account!])
        } catch {
            Logger.shared.error("Failed to update enabled state in account")
            sender.isOn = account.enabled
        }
    }

    
    @IBAction func showPassword(_ sender: UIButton) {
        account.password(reason: "Retrieve password for \(account.site.name)", context: nil, type: .ifNeeded) { (password, error) in
            if let error = error {
                Logger.shared.error("Could not get account", error: error)
            }
            guard let password = password else {
                Logger.shared.error("Account was nil")
                return
            }
            DispatchQueue.main.async {
                if self.userPasswordTextField.isEnabled {
                    self.userPasswordTextField.text = password
                    self.userPasswordTextField.isSecureTextEntry = !self.userPasswordTextField.isSecureTextEntry
                } else {
                    self.showHiddenPasswordPopup(password: password)
                }
            }
        }
    }
    
    @IBAction func deleteAccount(_ sender: UIButton) {
        let alert = UIAlertController(title: "popups.questions.delete_account".localized, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { action in
            self.performSegue(withIdentifier: "DeleteAccount", sender: self)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc func edit() {
        tableView.setEditing(true, animated: true)
        let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(update))
        doneButton.style = .done
        
        navigationItem.setRightBarButton(doneButton, animated: true)
        
        userNameTextField.isEnabled = true
        userPasswordTextField.isEnabled = true
        websiteNameTextField.isEnabled = true
        websiteURLTextField.isEnabled = true
        totpLoader?.isHidden = true

        editingMode = true
        UIView.transition(with: tableView,
                          duration: 0.1,
                          options: .transitionCrossDissolve,
                          animations: { self.tableView.reloadData() })
    }
    
    @objc func cancel() {
        endEditing()
        userPasswordTextField.text = password ?? "22characterplaceholder"
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
            if let oldPassword: String = password {
                newPassword = userPasswordTextField.text != oldPassword ? userPasswordTextField.text : nil
            }
            let newUrl = websiteURLTextField.text != account?.site.url ? websiteURLTextField.text : nil
            guard newPassword != nil || newUsername != nil || newSiteName != nil || newUrl != nil else {
                return
            }
            try account.update(username: newUsername, password: newPassword, siteName: newSiteName, url: newUrl, askToLogin: nil, askToChange: nil, enabled: nil)
            NotificationCenter.default.post(name: .accountUpdated, object: self, userInfo: ["account": account!])
            Logger.shared.analytics(.accountUpdated, properties: [
                .username: newUsername != nil,
                .password: newPassword != nil,
                .url: newUrl != nil,
                .siteName: newSiteName != nil
            ])
        } catch {
            Logger.shared.warning("Could not change username", error: error)
            userNameTextField.text = account?.username
            websiteNameTextField.text = account?.site.name
            websiteURLTextField.text = account?.site.url
        }
    }

    func updateAccount(account: Account) {
        self.account = account
        loadAccountData()
        NotificationCenter.default.post(name: .accountUpdated, object: self, userInfo: ["account": account])
    }
    
    // MARK: - Private
    
    private func endEditing() {
        tableView.setEditing(false, animated: true)
        userPasswordTextField.isSecureTextEntry = true
        navigationItem.setRightBarButton(editButton, animated: true)
        userNameTextField.isEnabled = false
        userPasswordTextField.isEnabled = false
        websiteNameTextField.isEnabled = false
        websiteURLTextField.isEnabled = false
        totpLoader?.isHidden = false
        
        editingMode = false
        UIView.transition(with: tableView,
                          duration: 0.1,
                          options: .transitionCrossDissolve,
                          animations: { self.tableView.reloadData() })
    }
    
    private func showHiddenPasswordPopup(password: String) {
        let showPasswordHUD = MBProgressHUD.showAdded(to: self.tableView.superview!, animated: true)
        showPasswordHUD.mode = .text
        showPasswordHUD.bezelView.color = .black
        showPasswordHUD.label.text = password
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
    }
    
    private func copyToPasteboard(_ indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        
        if indexPath.row == 1 {
            Logger.shared.analytics(.passwordCopied)
        } else {
            Logger.shared.analytics(.otpCopied)
        }
        
        let pasteBoard = UIPasteboard.general
        pasteBoard.string = indexPath.row == 1 ? userPasswordTextField.text : userCodeTextField.text
        
        let copiedLabel = UILabel(frame: cell.bounds)
        copiedLabel.text = "accounts.copied".localized
        copiedLabel.font = copiedLabel.font.withSize(18)
        copiedLabel.textAlignment = .center
        copiedLabel.textColor = .white
        copiedLabel.backgroundColor = UIColor(displayP3Red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        
        cell.addSubview(copiedLabel)
        
        UIView.animate(withDuration: 0.5, delay: 1.0, options: [.curveLinear], animations: {
            copiedLabel.alpha = 0.0
        }) { if $0 { copiedLabel.removeFromSuperview() } }
    }
    
    // MARK: OTP methods
    
    private func updateOTPUI() {
        if let token = token {
            qrEnabled = false
            totpLoaderWidthConstraint.constant = UITableViewCell.defaultHeight
            userCodeCell.updateConstraints()
            userCodeCell.accessoryView = nil
            userCodeTextField.text = token.currentPasswordSpaced
            switch token.generator.factor {
            case .counter(_):
                let button = UIButton(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
                button.imageEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
                button.setImage(UIImage(named: "refresh"), for: .normal)
                button.imageView?.contentMode = .scaleAspectFit
                button.addTarget(self, action: #selector(self.updateHOTP), for: .touchUpInside)
                totpLoader.addSubview(button)
            case .timer(let period):
                let start = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: period)
                loadingCircle?.removeCircleAnimation()
                totpLoader.subviews.forEach { $0.removeFromSuperview() }
                self.loadingCircle = FilledCircle(frame: CGRect(x: 12, y: 12, width: 20, height: 20))
                loadingCircle?.draw(color: UIColor.primary.cgColor, backgroundColor: UIColor.primary.cgColor)
                totpLoader.addSubview(self.loadingCircle!)
                self.otpCodeTimer = Timer.scheduledTimer(withTimeInterval: period - start, repeats: false, block: { (timer) in
                    self.userCodeTextField.text = token.currentPasswordSpaced
                    self.otpCodeTimer = Timer.scheduledTimer(timeInterval: period, target: self, selector: #selector(self.updateTOTP), userInfo: nil, repeats: true)
                })
                loadingCircle!.startCircleAnimation(duration: period, start: start)
            }
        } else {
            userCodeTextField.text = ""
            otpCodeTimer?.invalidate()
            qrEnabled = true
            loadingCircle?.removeCircleAnimation()
            totpLoader.subviews.forEach { $0.removeFromSuperview() }
            totpLoaderWidthConstraint.constant = 0
            userCodeCell.updateConstraints()
            userCodeCell.accessoryView = UIImageView(image: UIImage(named: "chevron_right"))
            userCodeTextField.placeholder = "accounts.scan_qr".localized
        }
    }
    
    @objc func updateHOTP() {
        if let token = token?.updatedToken() {
            self.token = token
            try? account.setOtp(token: token)
            userCodeTextField.text = token.currentPasswordSpaced
        }
    }
    
    @objc func updateTOTP() {
        userCodeTextField.text = token?.currentPasswordSpaced ?? ""
    }

    // MARK: - Navigation

    @IBAction func unwindToAccountViewController(sender: UIStoryboardSegue) {
        // TODO: This could also be used instead of canAddOtp delegate
        if let source = sender.source as? TokenController {
            if editingMode {
                endEditing()
            }
            self.token = source.token
            updateOTPUI()
        }
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "reportSite", let destination = segue.destination.contents as? ReportSiteViewController {
            guard let account = account else {
                return
            }
            destination.account = account
        } else if segue.identifier == "showQR", let destination = segue.destination as? OTPViewController {
            self.loadingCircle?.removeCircleAnimation()
            destination.account = account
        } else if segue.identifier == "ShowSiteOverview", let destination = segue.destination as? SiteTableViewController {
            destination.account = account
            destination.delegate = self
        }
    }
}
