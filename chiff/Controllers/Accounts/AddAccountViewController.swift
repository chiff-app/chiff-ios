/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class AddAccountViewController: KeynTableViewController, UITextFieldDelegate {

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
            nil,
            String(format: "accounts.notes_footer".localized.capitalizedFirstLetter, maxCharacters)
        ]
    }

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

    // MARK: - Actions

    @IBAction func showPassword(_ sender: UIButton) {
        passwordIsHidden = !passwordIsHidden
        passwordField.isSecureTextEntry = passwordIsHidden
        showPasswordButton.setImage(UIImage(named: passwordIsHidden ? "eye_logo" : "eye_logo_off"), for: .normal)
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }

    // MARK: UITextFieldDelegate

    @objc func textFieldDidChange(textField: UITextField) {
        updateSaveButtonState()
    }

    // MARK: - Actions

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // IMPORTANT: Override copy functionality
    }

    @IBAction func saveAccount(_ sender: Any) {
        createAccount()
    }

    // MARK: - Private

    private func updateSaveButtonState() {
        let siteName = siteNameField.text ?? ""
        let siteURL = siteURLField.text ?? ""
        let username = usernameField.text ?? ""
        let password = passwordField.text ?? ""

        if siteName.isEmpty || siteURL.isEmpty || username.isEmpty || password.isEmpty {
            saveButton.isEnabled = false
        } else {
            saveButton.isEnabled = true
        }
    }

    private func createAccount() {
        guard let websiteName = siteNameField.text,
           let websiteURL = siteURLField.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           let username = usernameField.text,
           let password = passwordField.text else {
            self.showAlert(message: "errors.save_account" + ".")
            return
        }
        do {
            guard let url = URL(string: websiteURL) ?? URL(string: "https://\(websiteURL)") else {
                throw AccountError.invalidURL
            }
            let id = url.absoluteString.lowercased().sha256
            let site = Site(name: websiteName, id: id, url: websiteURL, ppd: nil)
            self.account = try UserAccount(username: username, sites: [site], password: password, rpId: nil, algorithms: nil, notes: notesCell.textString, askToChange: nil, context: nil)
            self.performSegue(withIdentifier: "UnwindToAccountOverview", sender: self)
            Logger.shared.analytics(.accountAddedLocal)
        } catch KeychainError.duplicateItem {
            showAlert(message: "errors.account_exists".localized)
        } catch AccountError.invalidURL {
            showAlert(message: "errors.invalid_url".localized)
        } catch {
            showAlert(message: "\("errors.save_account".localized): \(error.localizedDescription)")
            Logger.shared.error("Account could not be saved", error: error)
        }
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
