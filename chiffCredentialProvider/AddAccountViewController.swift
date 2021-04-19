//
//  CredentialProviderAddAccountViewController.swift
//  chiffCredentialProvider
//
//  Copyright: see LICENSE.md
//

import UIKit
import AuthenticationServices
import ChiffCore
import PromiseKit

class AddAccountViewController: ChiffTableViewController, UITextFieldDelegate {

    override var headers: [String?] {
        return [
            "accounts.website_details".localized.capitalizedFirstLetter,
            "accounts.user_details".localized.capitalizedFirstLetter,
            "accounts.notes".localized.capitalizedFirstLetter
        ]
    }

    override var footers: [String?] {
        return [
            "accounts.url_warning".localized.capitalizedFirstLetter,
            "accounts.generate_password_footer".localized,
            String(format: "accounts.notes_footer".localized.capitalizedFirstLetter, maxCharacters)
        ]
    }

    var credentialExtensionContext: ASCredentialProviderExtensionContext!
    var serviceIdentifiers: [ASCredentialServiceIdentifier]!

    @IBOutlet weak var saveButton: UIBarButtonItem!
    @IBOutlet weak var siteNameField: UITextField!
    @IBOutlet weak var siteURLField: UITextField!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var showPasswordButton: UIButton!
    @IBOutlet weak var notesCell: MultiLineTextInputTableViewCell!

    private let ppd: PPD? = nil
    private var passwordIsHidden = true
    var account: UserAccount?

    override func viewDidLoad() {
        super.viewDidLoad()

        for textField in [siteNameField, siteURLField, usernameField, passwordField] {
            textField?.delegate = self
            textField?.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        }
        if let index = self.navigationController?.viewControllers.firstIndex(of: self), index == 0 {
            updateUI()
        }
        if let service = self.serviceIdentifiers.first {
            switch service.type {
            case .URL:
                if let url = URL(string: service.identifier) {
                    if let host = url.host {
                        self.siteNameField.text = host.starts(with: "www.") ? String(host.dropFirst(4)) : host
                        if let scheme = url.scheme {
                            self.siteURLField.text = "\(scheme)://\(host)"
                        }
                    }
                }
            case .domain:
                self.siteURLField.text = "https://\(service.identifier)"
                self.siteNameField.text = service.identifier.starts(with: "www.") ? String(service.identifier.dropFirst(4)) : service.identifier
            @unknown default:
                break
            }
        }

        notesCell.delegate = self

        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0

        tableView.separatorColor = UIColor.primaryTransparant

        updateSaveButtonState()
        Logger.shared.analytics(.addAccountOpened)
        reEnableBarButtonFont()
    }

    // MARK: - UITableView

    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return indexPath.section == 2 ? UITableView.automaticDimension : 44
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // IMPORTANT: Override copy functionality
    }

    // MARK: - Actions

    @IBAction func showPassword(_ sender: UIButton) {
        passwordIsHidden.toggle()
        passwordField.isSecureTextEntry = passwordIsHidden
        showPasswordButton.setImage(UIImage(named: passwordIsHidden ? "eye_logo" : "eye_logo_off"), for: .normal)
    }

    @IBAction func saveAccount(_ sender: Any) {
        createAccount()
    }

    // MARK: UITextFieldDelegate

    @objc func textFieldDidChange(textField: UITextField) {
        updateSaveButtonState()
    }

    // MARK: - Private functions

    private func updateSaveButtonState() {
        let siteName = siteNameField.text ?? ""
        let siteURL = siteURLField.text ?? ""
        let username = usernameField.text ?? ""

        if siteName.isEmpty || siteURL.isEmpty || username.isEmpty {
            saveButton.isEnabled = false
        } else {
            saveButton.isEnabled = true
        }
    }

    private func createAccount() {
        guard let websiteName = siteNameField.text,
           let websiteURL = siteURLField.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           let username = usernameField.text else {
            self.showAlert(message: "errors.save_account" + ".")
            return
        }
        let chosenPassword = (self.passwordField.text ?? "").isEmpty ? nil : self.passwordField.text!
        guard let url = URL(string: websiteURL) ?? URL(string: "https://\(websiteURL)") else {
            showAlert(message: "errors.invalid_url".localized)
            return
        }
        let id = url.absoluteString.lowercased().sha256
        firstly {
            PPD.get(id: id, organisationKeyPair: nil)
        }.done { ppd in
            let site = Site(name: websiteName, id: id, url: websiteURL, ppd: ppd)
            let account = try UserAccount(username: username, sites: [site], password: chosenPassword, rpId: nil, algorithms: nil, notes: self.notesCell.textString, askToChange: nil, context: nil)
            guard let password = try account.password() else {
                self.credentialExtensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
                return
            }
            let passwordCredential = ASPasswordCredential(user: account.username, password: password)
            self.credentialExtensionContext.completeRequest(withSelectedCredential: passwordCredential, completionHandler: nil)
            Logger.shared.analytics(.accountAddedLocal)
        }.catch { _ in
            self.credentialExtensionContext.cancelRequest(withError: NSError(domain: ASExtensionErrorDomain, code: ASExtensionError.failed.rawValue))
        }
    }

    private func updateUI() {
        UINavigationBar.appearance().setBackgroundImage(UIImage(), for: .default)
        UINavigationBar.appearance().shadowImage = UIImage()
        UINavigationBar.appearance().isTranslucent = true
        UINavigationBar.appearance().backIndicatorImage = UIImage(named: "chevron_left")?.withInsets(UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10))
        UINavigationBar.appearance().backIndicatorTransitionMaskImage =  UIImage(named: "chevron_left")?.withInsets(UIEdgeInsets(top: 0, left: 10, bottom: 0, right: 10))
        UIBarButtonItem.appearance().setTitleTextAttributes([.foregroundColor: UIColor.primary,
                                                             .font: UIFont.primaryBold!], for: UIControl.State.normal)
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: UIFont.primaryBold!], for: UIControl.State.highlighted)
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: UIFont.primaryBold!], for: UIControl.State.selected)
        UIBarButtonItem.appearance().setTitleTextAttributes([.font: UIFont.primaryBold!], for: UIControl.State.focused)
        UIBarButtonItem.appearance().setTitleTextAttributes([.foregroundColor: UIColor.primaryHalfOpacity,
                                                             .font: UIFont.primaryBold!], for: UIControl.State.disabled)
        let cancelButton = KeynBarButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
        cancelButton.setTitle("Cancel", for: .normal)
        cancelButton.addTarget(self, action: #selector(dismiss(sender:)), for: .touchUpInside)
        self.navigationItem.leftBarButtonItem = cancelButton.barButtonItem
    }

}

extension AddAccountViewController: MultiLineTextInputTableViewCellDelegate {

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
