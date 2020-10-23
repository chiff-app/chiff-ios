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
    @IBOutlet weak var requirementsView: UIView!
    @IBOutlet var requirementLabels: [UILabel]!
    @IBOutlet weak var requirementLabelsStackView: UIStackView!

    @IBOutlet weak var siteNameField: UITextField!
    @IBOutlet weak var siteURLField: UITextField!
    @IBOutlet weak var usernameField: UITextField!
    @IBOutlet weak var passwordField: UITextField!
    @IBOutlet weak var showPasswordButton: UIButton!
    @IBOutlet weak var notesCell: MultiLineTextInputTableViewCell!

    private let ppd: PPD? = nil
    private var passwordValidator: PasswordValidator?
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

        requirementLabels.sort(by: { $0.tag < $1.tag })

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

        updatePasswordRequirements(password: password)

        if siteName.isEmpty || siteURL.isEmpty || username.isEmpty || !isValidPassword(password: password) {
            saveButton.isEnabled = false
        } else {
            saveButton.isEnabled = true
        }
    }

    private func isValidPassword(password: String) -> Bool {
        if password.isEmpty {
            return false
        }

        if let passwordValidator = passwordValidator {
            return (try? passwordValidator.validate(password: password)) ?? false
        } else {
            return true
        }
    }

    // TODO: Fetch correct requirements from PPD and present to user.
    private func updatePasswordRequirements(password: String) {
        if let passwordValidator = passwordValidator {
            requirementLabels[0].text = passwordValidator.validateMinLength(password: password) ? "" : "\u{26A0} The password needs to be at least \(8) characters."
            requirementLabels[1].text = passwordValidator.validateMaxLength(password: password) ? "" : "\u{26A0} The password can have no more than \(50) characters."
            requirementLabels[2].text = passwordValidator.validateCharacters(password: password) ? "" : "\u{26A0} The password has invalid characters."
            requirementLabels[3].text = (try? passwordValidator.validateCharacterSet(password: password)) ?? false ? "" : "\u{26A0} CharacterSet constraint"
            requirementLabels[4].text = passwordValidator.validateConsecutiveCharacters(password: password)
                ? ""
                : "\u{26A0} The password can't have more than n consecutive characters like aaa or ***."
            requirementLabels[5].text = (try? passwordValidator.validatePositionRestrictions(password: password)) ?? false ? "" : "\u{26A0} The password needs to start with a mysterious character."
            requirementLabels[6].text = (try? passwordValidator.validateRequirementGroups(password: password)) ?? false ? "" : "\u{26A0} There are complicted rules for this PPD. Just try something."
            requirementLabels[7].text = passwordValidator.validateConsecutiveOrderedCharacters(password: password) ? "" : "\u{26A0} The password can't have consecutive characters like abc pr 0123."
        }
    }

    // TODO: How do we save accounts when there is no Site object? This happens when a user adds an account manually.
    private func createAccount() {
        if let websiteName = siteNameField.text,
           let websiteURL = siteURLField.text?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
           let username = usernameField.text,
           let password = passwordField.text {
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
