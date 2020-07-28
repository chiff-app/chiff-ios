/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import MBProgressHUD
import OneTimePassword
import QuartzCore
import PromiseKit

class AccountViewController: KeynTableViewController, UITextFieldDelegate, SitesDelegate {

    override var headers: [String?] {
        return [
            "accounts.website_details".localized.capitalizedFirstLetter,
            "accounts.user_details".localized.capitalizedFirstLetter,
            "accounts.notes".localized.capitalizedFirstLetter
        ]
    }

    override var footers: [String?] {
        return [
            shadowing ? "accounts.shadowing_warning".localized : webAuthnEnabled ? "accounts.webauthn_enabled".localized.capitalizedFirstLetter : "accounts.url_warning".localized.capitalizedFirstLetter,
            "accounts.2fa_description".localized.capitalizedFirstLetter,
            String(format: "accounts.notes_footer".localized.capitalizedFirstLetter, maxCharacters),
            showAccountEnableButton ? "accounts.footer_account_enabled".localized.capitalizedFirstLetter : nil
        ]
    }

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
    @IBOutlet weak var addToTeamButton: KeynButton!
    @IBOutlet weak var notesCell: MultiLineTextInputTableViewCell!

    var editButton: UIBarButtonItem!
    var account: Account!
    var passwordLoaded = false
    var tap: UITapGestureRecognizer!
    var qrEnabled: Bool = true
    var editingMode: Bool = false
    var otpCodeTimer: Timer?
    var token: Token?
    var loadingCircle: FilledCircle?
    var showAccountEnableButton: Bool = false
    var canEnableAccount: Bool = true
    var session: TeamSession?   // Only set if user is team admin
    var team: Team?             // Only set if user is team admin

    var password: String? {
        return try? account.password()
    }

    var webAuthnEnabled: Bool {
        if let account = account as? UserAccount {
            return account.webAuthn != nil
        } else {
            return false
        }
    }

    var shadowing: Bool {
        if let account = account as? UserAccount {
            return account.shadowing
        } else {
            return false
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        editButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.edit, target: self, action: #selector(edit))
        editButton.isEnabled = account is UserAccount
        canEnableAccount = account is UserAccount
        navigationItem.rightBarButtonItem = editButton
        notesCell.textView.isEditable = false
        notesCell.delegate = self

        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0
        tableView.separatorColor = UIColor.primaryTransparant
        setAddToTeamButton()
        loadAccountData()

        tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))

        NotificationCenter.default.addObserver(forName: .accountsLoaded, object: nil, queue: OperationQueue.main, using: reloadAccount)
        NotificationCenter.default.addObserver(forName: .sharedAccountsChanged, object: nil, queue: OperationQueue.main, using: reloadAccount)

        reEnableBarButtonFont()
    }

    private func setAddToTeamButton() {
        // TODO: Handle situation where there are multiple admin sessions
        if let session = (try? TeamSession.all())?.first(where: { $0.isAdmin }) {
            addToTeamButton.isHidden = false
            addToTeamButton.isEnabled = true
            addToTeamButton.setTitle(account is SharedAccount ? "accounts.move_from_team".localized : "accounts.add_to_team".localized, for: .normal)
            bottomSpacer.frame = CGRect(x: bottomSpacer.frame.minX, y: bottomSpacer.frame.minY, width: bottomSpacer.frame.width, height: 100)
            self.session = session
        } else {
            addToTeamButton.isEnabled = false
            addToTeamButton.isHidden = true
            bottomSpacer.frame = CGRect(x: bottomSpacer.frame.minX, y: bottomSpacer.frame.minY, width: bottomSpacer.frame.width, height: showAccountEnableButton ? 40.0 : 0)
        }
    }

    private func reloadAccount(notification: Notification) {
        DispatchQueue.main.async {
            do {
                if let oldAccount = self.account as? UserAccount {
                    self.account = try UserAccount.get(id: oldAccount.id, context: nil)
                } else if let oldAccount  = self.account as? SharedAccount {
                    self.account = try SharedAccount.get(id: oldAccount.id, context: nil)
                }
                guard self.account != nil else {
                    self.performSegue(withIdentifier: "DeleteAccount", sender: self)
                    return
                }
                self.loadAccountData()
            } catch {
                Logger.shared.warning("Failed to update accounts in UI", error: error)
            }
        }
    }

    private func loadAccountData() {
        websiteNameTextField.text = account.site.name
        websiteURLTextField.text = account.site.url
        userNameTextField.text = account.username
        enabledSwitch.isOn = account.enabled
        enabledSwitch.isEnabled = account.enabled || canEnableAccount
        websiteNameTextField.delegate = self
        websiteURLTextField.delegate = self
        userNameTextField.delegate = self
        userPasswordTextField.delegate = self
        do {
            if !account.hasPassword {
                userPasswordTextField.placeholder = "accounts.no_password".localized
                userPasswordTextField.isSecureTextEntry = false
                showPasswordButton.isHidden = true
                showPasswordButton.isEnabled = false
            } else {
                if let password = password {
                    passwordLoaded = true
                    userPasswordTextField.text = password
                } else {
                    userPasswordTextField.text = "22characterplaceholder"
                }
                userPasswordTextField.isSecureTextEntry = true
            }
            token = try account.oneTimePasswordToken()
            notesCell.textString = try account.notes() ?? ""
            updateOTPUI()
        } catch AccountError.tokenRetrieval {
            showAlert(message: "errors.otp_fetch".localized)
        } catch {
            Logger.shared.error("Error loading accountData", error: error)
        }
    }

    // MARK: - UITableView

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if (indexPath.section == 1 && indexPath.row == 2 && token == nil) || (indexPath.section == 0 && indexPath.row == 1 && account.sites.count > 1) {
            cell.accessoryView = UIImageView(image: UIImage(named: "chevron_right"))
        }
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        return editingMode || showAccountEnableButton ? 4 : 3
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        super.tableView(tableView, willDisplayFooterView: view, forSection: section)
        guard section < 2 || showAccountEnableButton else {
            return
        }
        let footer = view as! UITableViewHeaderFooterView
        switch section {
        case 0:
            footer.textLabel?.isHidden = !(shadowing || webAuthnEnabled || tableView.isEditing)
        case 1:
            footer.textLabel?.isHidden = false
        case 2:
            footer.textLabel?.isHidden = true
        case 3:
            footer.textLabel?.isHidden = false
        default:
            fatalError("An extra section appeared!")
        }
    }
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1 && indexPath.row == 2 && token != nil && tableView.isEditing && account is UserAccount
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        guard var account = self.account as? UserAccount else {
            fatalError("Should not be able to edit sharedAccount")
        }
        try? account.deleteOtp()
        self.token = nil
        DispatchQueue.main.async {
            self.updateOTPUI()
        }
        tableView.cellForRow(at: indexPath)?.setEditing(false, animated: true)

    }

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        if indexPath.section == 3 && showAccountEnableButton && indexPath.row > 0 {
            return editingMode ? tableView.rowHeight : 0
        } else if indexPath.section == 3 && !showAccountEnableButton && indexPath.row == 0 {
            return 0.5 // So we still have a border
        }
        return indexPath.section == 2 ? UITableView.automaticDimension : 44
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            if indexPath.row == 1 && account.sites.count > 1 && account is UserAccount {
                performSegue(withIdentifier: "ShowSiteOverview", sender: self)
            }
        } else if indexPath.section == 1 {
            if (indexPath.row == 1 || (indexPath.row == 2 && !qrEnabled)) && password != nil {
                copyToPasteboard(indexPath)
            } else if indexPath.row == 2 && qrEnabled && account is UserAccount {
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
        guard var account = self.account as? UserAccount else {
            return
        }
        do {
            try account.update(username: nil, password: nil, siteName: nil, url: nil, askToLogin: nil, askToChange: nil, enabled: sender.isOn)
            NotificationCenter.default.postMain(name: .accountUpdated, object: self, userInfo: ["account": account])
        } catch {
            Logger.shared.error("Failed to update enabled state in account")
            sender.isOn = account.enabled
        }
    }

    
    @IBAction func showPassword(_ sender: UIButton) {
        //TODO: THis function should be disabled if there's no password
        if passwordLoaded && userPasswordTextField.isEnabled {
            self.userPasswordTextField.isSecureTextEntry = !self.userPasswordTextField.isSecureTextEntry
            return
        }
        firstly {
            account.password(reason: String(format: "popups.questions.retrieve_password".localized, account.site.name), context: nil, type: .ifNeeded)
        }.done(on: .main) { password in
            if self.userPasswordTextField.isEnabled {
                self.userPasswordTextField.isSecureTextEntry = !self.userPasswordTextField.isSecureTextEntry
            } else {
                self.showHiddenPasswordPopup(password: password ?? "This account has no password")
            }
        }.catchLog("Could not get account")
    }
    
    @IBAction func addToTeam(_ sender: KeynButton) {
        sender.showLoading()
        guard let session = session else {
            fatalError("Session must exist if this action is called")
        }
        if let account = account as? SharedAccount {
            let alert = UIAlertController(title: "popups.questions.move_to_user_account_title".localized, message: "popups.questions.move_to_user_account_message".localized, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: { action in
                sender.hideLoading()
            }))
            alert.addAction(UIAlertAction(title: "popups.responses.move".localized, style: .destructive, handler: { action in
                firstly {
                    self.removeAccountFromTeam(session: session, account: account)
                }.ensure {
                    sender.hideLoading()
                }.catch(on: .main) { error in
                    self.showAlert(message: "\("errors.move_from_team".localized): \(error)")
                }
            }))
            self.present(alert, animated: true, completion: nil)
        } else {
            firstly {
                session.getTeamSeed()
            }.then {
                Team.get(seed: $0)
            }.ensure(on: .main) {
                sender.hideLoading()
            }.done(on: .main) {
                self.team = $0
                self.performSegue(withIdentifier: "AddToTeam", sender: self)
            }.catch(on: .main) { error in
                self.showAlert(message: "\("errors.add_to_team".localized): \(error)")
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
        reEnableBarButtonFont()
        
        userNameTextField.isEnabled = true
        userPasswordTextField.isEnabled = true
        websiteNameTextField.isEnabled = true
        websiteURLTextField.isEnabled = true
        notesCell.textView.isEditable = true
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
        guard var account = self.account as? UserAccount else {
            return
        }
        endEditing()
        do {
            var newPassword: String? = nil
            let newUsername = userNameTextField.text != account.username ? userNameTextField.text : nil
            let newSiteName = websiteNameTextField.text != account.site.name ? websiteNameTextField.text : nil
            if let oldPassword: String = password {
                newPassword = userPasswordTextField.text != oldPassword ? userPasswordTextField.text : nil
            } else {
                newPassword = userPasswordTextField.text
            }
            let newUrl = websiteURLTextField.text != account.site.url ? websiteURLTextField.text : nil
            if try notesCell.textString != account.notes() {
                try account.updateNotes(notes: notesCell.textString)
            }
            guard newPassword != nil || newUsername != nil || newSiteName != nil || newUrl != nil else {
                return
            }
            try account.update(username: newUsername, password: newPassword, siteName: newSiteName, url: newUrl, askToLogin: nil, askToChange: nil, enabled: nil)
            NotificationCenter.default.postMain(name: .accountUpdated, object: self, userInfo: ["account": account])
            if newPassword != nil {
                showPasswordButton.isHidden = false
                showPasswordButton.isEnabled = true
            }
            Logger.shared.analytics(.accountUpdated, properties: [
                .username: newUsername != nil,
                .password: newPassword != nil,
                .url: newUrl != nil,
                .siteName: newSiteName != nil
            ])
        } catch {
            Logger.shared.warning("Could not change username", error: error)
            userNameTextField.text = account.username
            websiteNameTextField.text = account.site.name
            websiteURLTextField.text = account.site.url
        }
    }

    func updateAccount(account: UserAccount) {
        self.account = account
        loadAccountData()
        NotificationCenter.default.postMain(name: .accountUpdated, object: self, userInfo: ["account": account])
    }
    
    // MARK: - Private

    private func removeAccountFromTeam(session: TeamSession, account: SharedAccount) -> Promise<Void> {
        do {
            let password = try account.password()
            let notes = try account.notes()
            return firstly {
                session.getTeamSeed()
            }.then {
                Team.get(seed: $0)
            }.then {
                $0.deleteAccount(id: account.id)
            }.then {
                TeamSession.updateTeamSession(session: session).asVoid()
            }.map(on: .main) {
                guard try SharedAccount.get(id: account.id, context: nil) == nil else {
                    throw KeychainError.storeKey
                }
                self.account = try UserAccount(username: account.username, sites: account.sites, password: password, rpId: nil, algorithms: nil, notes: notes, askToChange: nil, context: nil)
                self.addToTeamButton.originalButtonText = "accounts.add_to_team".localized
            }.asVoid()
        } catch {
            return Promise(error: error)
        }
    }
    
    private func endEditing() {
        tableView.setEditing(false, animated: true)
        userPasswordTextField.isSecureTextEntry = true
        navigationItem.setRightBarButton(editButton, animated: true)
        userNameTextField.isEnabled = false
        userPasswordTextField.isEnabled = false
        websiteNameTextField.isEnabled = false
        websiteURLTextField.isEnabled = false
        notesCell.textView.isEditable = false
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
        if let token = token?.updatedToken(), var account = self.account as? UserAccount {
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
            guard let account = account as? UserAccount else {
                fatalError("Should not be able to open OTP controller on shared account")
            }
            destination.account = account
        } else if segue.identifier == "ShowSiteOverview", let destination = segue.destination as? SiteTableViewController {
            guard let account = account as? UserAccount else {
                fatalError("Should not be able to open site overview on shared account")
            }
            destination.account = account
            destination.delegate = self
        } else if segue.identifier == "AddToTeam", let destination = segue.destination.contents as? TeamAccountViewController {
            destination.session = session!
            destination.account = account!
            destination.team = team!
        }
    }
}

extension AccountViewController: MultiLineTextInputTableViewCellDelegate {

    var maxCharacters: Int {
        return 4000
    }

    var placeholderText: String {
        return "accounts.notes_placeholder".localized
    }

    func textViewHeightDidChange(_ cell: UITableViewCell) {
        UIView.setAnimationsEnabled(false)
        tableView?.beginUpdates()
        tableView?.endUpdates()
        UIView.setAnimationsEnabled(true)

        if let thisIndexPath = tableView?.indexPath(for: cell) {
            tableView?.scrollToRow(at: thisIndexPath, at: .bottom, animated: false)
        }
    }

}
