//
//  RecoveryViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore
import PromiseKit

enum RecoveryError: Error {
    case unauthenticated
}

class RecoveryViewController: UIViewController, UITextFieldDelegate {
    var isInitialSetup = true
    var wordlists: [[String]]!

    private var keyboardHeight: CGFloat?
    private var initialContentOffset: CGPoint!

    @IBOutlet var contentView: UIView!
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var wordTextFields: [UITextField]!
    @IBOutlet var activityViewContainer: UIView!
    @IBOutlet var finishButton: UIBarButtonItem!
    @IBOutlet var wordTextFieldsStack: UIStackView!
    @IBOutlet var constraintContentHeight: NSLayoutConstraint!

    var mnemonic = [String](repeating: "", count: 12) {
        didSet {
            finishButton.isEnabled = checkMnemonic()
        }
    }

    // MARK: - UIViewControllerLifeCycle

    override func viewDidLoad() {
        super.viewDidLoad()
        initialSetup()
        Logger.shared.analytics(.restoreBackupOpened, override: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        initialContentOffset = scrollView.contentOffset
        checkSeedSeed()
    }

    // MARK: - InitialSetup

    func initialSetup() {
        fillTextFields()
        setWordList()
        setKeyboardHandlers()
        navigationItem.rightBarButtonItem?.setColor(color: .white)
    }

    func checkSeedSeed() {
        guard !Seed.hasKeys else {
            seedExistsError()
            return
        }
    }

    func fillTextFields() {
        wordTextFields?.sort(by: { $0.tag < $1.tag })
        for textField in wordTextFields {
            initialize(textfield: textField)
        }
    }

    func setWordList() {
        do {
            wordlists = try Seed.wordlists()
        } catch {
            showAlert(message: "errors.loading_wordlist".localized)
        }
    }

    func setKeyboardHandlers() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        view.addEndEditingTapGesture()
    }

    // MARK: - StatusBarStyle

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    // MARK: - UITextFieldDelegate

    func textFieldDidBeginEditing(_ textField: UITextField) {
        if let keyboardHeight = keyboardHeight {
            let currentContentOffset = CGPoint(x: 0, y: contentView.convert(textField.superview!.frame.origin, to: scrollView).y - (textField.frame.size.height * 1.4) - keyboardHeight)
            scrollView.setContentOffset(currentContentOffset, animated: true)
        }
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard.
        if let currentIndex = wordTextFields.firstIndex(of: textField), currentIndex < wordTextFields.count - 1 {
            wordTextFields[currentIndex + 1].becomeFirstResponder()
        } else {
            textField.resignFirstResponder()
            if checkMnemonic() {
                finish(nil)
            }
        }
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        checkWord(for: textField)
        scrollView.setContentOffset(initialContentOffset, animated: true)
    }

    @objc func textFieldDidChange(textField: UITextField) {
        checkWord(for: textField)
    }

    // MARK: - KeyboardAppearance

    @objc func keyboardWillShow(notification: Notification) {
        guard keyboardHeight == nil else {
            return
        }
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            keyboardHeight = keyboardSize.height + view.safeAreaInsets.bottom
        }
        if let textView = view.firstResponder as? UITextField {
            textFieldDidBeginEditing(textView)
        }
    }

    // MARK: - Actions

    @IBAction func back(_ sender: UIBarButtonItem) {
        navigationController?.popViewController(animated: true)
    }

    @IBAction func finish(_ sender: UIBarButtonItem?) {
        view.endEditing(false)
        activityViewContainer.isHidden = false
        firstly {
            LocalAuthenticationManager.shared.authenticate(reason: "popups.questions.restore_accounts".localized, withMainContext: true)
        }.then { context -> Promise<(RecoveryResult, RecoveryResult)> in
            Seed.recover(context: context, mnemonic: self.mnemonic)
        }.ensure(on: .main) {
            self.activityViewContainer.isHidden = true
        }.done { accountResult, teamResult in
            var message: String?
            if accountResult.failed > 0, teamResult.failed > 0 {
                message = String(format: "errors.failed_teams_and_accounts_message".localized, accountResult.failed, accountResult.total, teamResult.failed, teamResult.total)
            } else if accountResult.failed > 0 {
                message = String(format: "errors.failed_accounts_message".localized, accountResult.failed, accountResult.total)
            } else if teamResult.failed > 0 {
                message = String(format: "errors.failed_teams_message".localized, teamResult.failed, teamResult.total)
            }
            if let message = message {
                let alert = UIAlertController(title: "errors.failed_accounts_title".localized, message: message, preferredStyle: .alert)
                alert.addAction(UIAlertAction(title: "OK", style: .default, handler: { _ in
                    self.onSeedRecoverySuccess()
                }))
                self.present(alert, animated: true)
            } else {
                self.onSeedRecoverySuccess()
            }
        }.catch(on: .main) { error in
            Logger.shared.error("Error restoring backup", error: error)
            self.showAlert(message: "errors.seed_restore".localized)
            self.activityViewContainer.isHidden = true
        }
    }

    // MARK: - Private functions

    private func onSeedRecoverySuccess() {
        Properties.agreedWithTerms = true // If a seed is recovered, user has agreed at that time.
        registerForPushNotifications()
        Logger.shared.analytics(.backupRestored, override: true)
    }

    private func showRootController() {
        guard let window = AppDelegate.shared.startupService.window else {
            return
        }
        guard let rootController = UIStoryboard.main.instantiateViewController(withIdentifier: "RootController") as? RootViewController else {
            Logger.shared.error("Unexpected root view controller type")
            fatalError("Unexpected root view controller type")
        }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            DispatchQueue.main.async {
                window.rootViewController = rootController
            }
        })
    }

    private func checkMnemonic() -> Bool {
        guard mnemonic.allSatisfy({ !$0.isEmpty }) else {
            return false
        }
        return Seed.validate(mnemonic: mnemonic)
    }

    private func checkWord(for textField: UITextField) {
        if let word = textField.text, !word.isEmpty, (wordlists.contains { $0.contains(word) }) {
            mnemonic[textField.tag] = word
            UIView.animate(withDuration: 0.1) {
                textField.rightView?.alpha = 1.0
            }
        } else {
            mnemonic[textField.tag] = ""
            if let alpha = textField.rightView?.alpha, alpha > 0.0 {
                UIView.animate(withDuration: 0.1) {
                    textField.rightView?.alpha = 0.0
                }
            }
        }
    }

    private func initialize(textfield: UITextField) {
        let checkMarkImageView = UIImageView(image: UIImage(named: "checkmark_small"))
        checkMarkImageView.contentMode = UIView.ContentMode.center
        if let size = checkMarkImageView.image?.size {
            checkMarkImageView.translatesAutoresizingMaskIntoConstraints = false
            checkMarkImageView.widthAnchor.constraint(equalToConstant: size.width + 40.0).isActive = true
            checkMarkImageView.heightAnchor.constraint(equalToConstant: size.height).isActive = true
        }

        textfield.placeholder = "\("backup.word".localized.capitalizedFirstLetter) \(textfield.tag + 1)"
        textfield.rightViewMode = .always
        textfield.rightView = checkMarkImageView
        textfield.rightView?.alpha = 0.0
        textfield.delegate = self
        textfield.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
    }

    private func seedExistsError() {
        let alert = UIAlertController(title: "errors.seed_exists".localized, message: "popups.questions.delete_existing".localized, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: { _ in
            self.navigationController?.popViewController(animated: true)
        }))
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { _ in
            firstly {
                BrowserSession.deleteAll()
            }.then { (_) -> Promise<Void> in
                TeamSession.purgeSessionDataFromKeychain()
                UserAccount.deleteAll()
                Seed.delete(includeSeed: true)
                return NotificationManager.shared.unregisterDevice()
            }.catchLog("Error deleting data")
        }))
        present(alert, animated: true, completion: nil)
    }

    private func registerForPushNotifications() {
        firstly {
            PushNotifications.register()
        }.done(on: DispatchQueue.main) { _ in
            self.showRootController()
        }
    }
}
