//
//  AccountViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import OneTimePassword
import QuartzCore
import PromiseKit
import ChiffCore

class AccountViewController: ChiffTableViewController, TokenHandler {

    override var headers: [String?] {
        return [
            "accounts.website_details".localized.capitalizedFirstLetter,
            "accounts.user_details".localized.capitalizedFirstLetter,
            "accounts.notes".localized.capitalizedFirstLetter
        ]
    }

    override var footers: [String?] {
        return [
            shadowing
                ? "accounts.shadowing_warning".localized
                : webAuthnEnabled
                ? "accounts.webauthn_enabled".localized.capitalizedFirstLetter
                : "accounts.url_warning".localized.capitalizedFirstLetter,
            "accounts.2fa_description".localized.capitalizedFirstLetter,
            String(format: "accounts.notes_footer".localized.capitalizedFirstLetter, maxCharacters)
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
    @IBOutlet weak var bottomSpacer: UIView!
    @IBOutlet weak var addToTeamButton: KeynButton!
    @IBOutlet weak var notesCell: MultiLineTextInputTableViewCell!

    var editButton: UIBarButtonItem!
    var account: Account!
    var passwordLoaded = false
    var tap: UITapGestureRecognizer!
    var passwordPopup: UIView?
    var qrEnabled: Bool = true
    var editingMode: Bool = false
    var token: Token?
    var loadingCircle: FilledCircle?
    var session: TeamSession?   // Only set if user is team admin
    var team: Team?             // Only set if user is team admin

    var password: String? {
        return try? account.password()
    }

    var webAuthnEnabled: Bool {
        return (account as? UserAccount)?.webAuthn != nil
    }

    var shadowing: Bool {
        return (account as? UserAccount)?.shadowing ?? false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        notesCell.textView.isEditable = false
        notesCell.delegate = self

        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0
        tableView.separatorColor = UIColor.primaryTransparant

        initializeEditing()
        setAddToTeamButton()
        loadAccountData(dismiss: true)

        tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(reloadAccount(notification:)), name: .accountsLoaded, object: nil)
        nc.addObserver(self, selector: #selector(reloadAccount(notification:)), name: .sharedAccountsChanged, object: nil)
        nc.addObserver(self, selector: #selector(reloadAccount(notification:)), name: .accountUpdated, object: UserAccount.self)

        reEnableBarButtonFont()
    }

    func loadAccountData(dismiss: Bool) {
        func authenticate() {
            firstly {
                LocalAuthenticationManager.shared.authenticate(reason: String(format: "popups.questions.retrieve_account".localized, account.site.name), withMainContext: true)
            }.map(on: .main) { _ in
                try self.loadKeychainData()
            }.catch(on: .main) { error in
                if dismiss {
                    self.navigationController?.popViewController(animated: true)
                }
                Logger.shared.error("Error loading accountData", error: error)
            }
        }
        websiteNameTextField.text = account.site.name
        websiteURLTextField.text = account.site.url
        userNameTextField.text = account.username
        websiteNameTextField.delegate = self
        websiteURLTextField.delegate = self
        userNameTextField.delegate = self
        userPasswordTextField.delegate = self
        if LocalAuthenticationManager.shared.isAuthenticated {
            do {
                try self.loadKeychainData()
            } catch KeychainError.interactionNotAllowed {
                // For some reasons isAuthenticated returns true if the user cancelled the operation, but Keychain still throws
                authenticate()
            } catch {
                Logger.shared.error("Error loading accountData", error: error)
            }
        } else {
            authenticate()
        }
    }

    func updateHOTP() {
        if let token = token?.updatedToken() {
            self.token = token
            if var account = self.account as? UserAccount {
                try? account.setOtp(token: token)
            }
            userCodeTextField.text = token.currentPasswordSpaced
        }
    }

    // MARK: - Actions

    @IBAction func showPassword(_ sender: UIButton) {
        guard account.hasPassword else {
            return
        }
        if passwordLoaded && userPasswordTextField.isEnabled {
            self.userPasswordTextField.isSecureTextEntry.toggle()
            return
        }
        firstly {
            account.password(reason: String(format: "popups.questions.retrieve_password".localized, account.site.name), context: nil, type: .ifNeeded)
        }.done(on: .main) { password in
            if self.userPasswordTextField.isEnabled {
                self.userPasswordTextField.isSecureTextEntry.toggle()
            } else {
                self.showHiddenPasswordPopup(password: password ?? "This account has no password")
            }
            try self.loadKeychainData()
        }.catchLog("Could not get account")
    }

    @IBAction func deleteAccount(_ sender: UIButton) {
        let alert = UIAlertController(title: "popups.questions.delete_account".localized, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { _ in
            self.performSegue(withIdentifier: "DeleteAccount", sender: self)
        }))
        self.present(alert, animated: true, completion: nil)
    }

    // MARK: - Navigation

    @IBAction func unwindToAccountViewController(sender: UIStoryboardSegue) {
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
        if segue.identifier == "showQR", let destination = segue.destination as? OTPViewController {
            self.loadingCircle?.removeCircleAnimation()
            guard let account = account as? UserAccount else {
                fatalError("Should not be able to open OTP controller on shared account")
            }
            destination.account = account
            destination.siteName = account.site.name
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

    // MARK: - Private functions

    @objc private func reloadAccount(notification: Notification) {
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
                self.loadAccountData(dismiss: false)
            } catch {
                Logger.shared.warning("Failed to update accounts in UI", error: error)
            }
        }
    }

    private func loadKeychainData() throws {
        if !account.hasPassword {
            userPasswordTextField.placeholder = "accounts.no_password".localized
            userPasswordTextField.isSecureTextEntry = false
            showPasswordButton.isHidden = true
            showPasswordButton.isEnabled = false
        } else {
            passwordLoaded = true
            showPasswordButton.isHidden = false
            showPasswordButton.isEnabled = true
            userPasswordTextField.text = password
            userPasswordTextField.isSecureTextEntry = true
        }
        self.token = try self.account.oneTimePasswordToken()
        self.notesCell.textString = try self.account.notes() ?? ""
        updateOTPUI()
    }

    @objc func hidePasswordPopup() {
        if let popup = self.passwordPopup {
            UIView.transition(with: self.tableView.superview!, duration: 0.1, options: .transitionCrossDissolve) {
                popup.isHidden = true
            } completion: { _ in
                popup.removeFromSuperview()
                self.passwordPopup = nil
            }
        }
    }

    private func showHiddenPasswordPopup(password: String) {
        guard self.passwordPopup == nil else {
            hidePasswordPopup()
            return
        }

        let passwordPopup = UIView()
        passwordPopup.backgroundColor = .primaryDark
        passwordPopup.layer.cornerRadius = 5
        passwordPopup.layer.masksToBounds = true
        passwordPopup.translatesAutoresizingMaskIntoConstraints = false
        passwordPopup.isHidden = true

        let textView = UILabel()
        textView.text = password
        textView.font = UIFont(name: "Courier New", size: 24)
        textView.textColor = .white
        textView.lineBreakMode = .byCharWrapping
        textView.numberOfLines = 0
        textView.textAlignment = .center
        textView.translatesAutoresizingMaskIntoConstraints = false

        passwordPopup.addSubview(textView)
        self.tableView.superview?.addSubview(passwordPopup)
        NSLayoutConstraint.activate([
            textView.topAnchor.constraint(equalTo: passwordPopup.topAnchor, constant: 8),
            textView.bottomAnchor.constraint(equalTo: passwordPopup.bottomAnchor, constant: -8),
            textView.leadingAnchor.constraint(equalTo: passwordPopup.leadingAnchor, constant: 8),
            textView.trailingAnchor.constraint(equalTo: passwordPopup.trailingAnchor, constant: -8),
            passwordPopup.centerYAnchor.constraint(equalTo: self.tableView.superview!.centerYAnchor),
            passwordPopup.centerXAnchor.constraint(equalTo: self.tableView.superview!.centerXAnchor),
            passwordPopup.leadingAnchor.constraint(greaterThanOrEqualTo: self.tableView.superview!.leadingAnchor, constant: 32),
            passwordPopup.trailingAnchor.constraint(greaterThanOrEqualTo: self.tableView.superview!.trailingAnchor, constant: -32)
        ])
        passwordPopup.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(hidePasswordPopup)))
        self.passwordPopup = passwordPopup
        UIView.transition(with: self.tableView.superview!, duration: 0.1, options: .transitionCrossDissolve) {
            passwordPopup.isHidden = false
        }
    }
}
