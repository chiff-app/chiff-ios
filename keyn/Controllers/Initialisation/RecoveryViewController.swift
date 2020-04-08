/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import PromiseKit

enum RecoveryError: KeynError {
    case unauthenticated
}

class RecoveryViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet var wordTextFields: Array<UITextField>!
    @IBOutlet weak var wordTextFieldsStack: UIStackView!
    @IBOutlet weak var finishButton: UIBarButtonItem!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var constraintContentHeight: NSLayoutConstraint!
    @IBOutlet weak var activityViewContainer: UIView!

    private let lowerBoundaryOffset: CGFloat = 15
    private let keyboardHeightOffset: CGFloat = 20
    
    private var textFieldOffset: CGPoint!
    private var textFieldHeight: CGFloat!
    private var keyboardHeight: CGFloat?
    
    var mnemonic = Array<String>(repeating: "", count: 12) {
        didSet {
            finishButton.isEnabled = checkMnemonic()
        }
    }

    var isInitialSetup = true
    let wordlists = try! Seed.wordlists()

    override func viewDidLoad() {
        super.viewDidLoad()
        wordTextFields?.sort(by: { $0.tag < $1.tag })
        for textField in wordTextFields! {
            initialize(textfield: textField)
        }

        // Observe keyboard change
        let nc = NotificationCenter.default
        nc.addObserver(forName: UIResponder.keyboardWillShowNotification, object: nil, queue: OperationQueue.main, using: keyboardWillShow)
        nc.addObserver(forName: UIResponder.keyboardWillHideNotification, object: nil, queue: OperationQueue.main, using: keyboardWillHide)
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
        navigationItem.rightBarButtonItem?.setColor(color: .white)
        Logger.shared.analytics(.restoreBackupOpened, override: true)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !Seed.hasKeys else {
            seedExistsError()
            return
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }

    // MARK: - UITextFieldDelegate
    
    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        textFieldOffset = textField.convert(textField.frame.origin, to: self.scrollView)
        textFieldHeight = textField.frame.size.height
        return true
    }
    
    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard.
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        checkWord(for: textField)
    }

    @objc func textFieldDidChange(textField: UITextField){
        checkWord(for: textField)
    }
    
    func keyboardWillShow(notification: Notification) {
        guard keyboardHeight == nil else {
            return
        }

        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            keyboardHeight = keyboardSize.height + view.safeAreaInsets.bottom
            let distanceToKeyboard = (textFieldOffset.y + textFieldHeight) - (scrollView.frame.size.height - keyboardSize.height)
            UIView.animate(withDuration: 0.3, animations: {
                self.constraintContentHeight.constant += (self.keyboardHeight!) // Just assigned so it makes sense to force unwrap
                if distanceToKeyboard > 0 {
                    self.scrollView.contentOffset = CGPoint(x: self.scrollView.frame.origin.x, y: (distanceToKeyboard + self.lowerBoundaryOffset))
                }
            })
        }
    }
    
    func keyboardWillHide(notification: Notification) {
        if let keyboardHeight = keyboardHeight {
            let distanceToKeyboard = (textFieldOffset.y + textFieldHeight) - (scrollView.frame.size.height - keyboardHeight) + self.lowerBoundaryOffset
            UIView.animate(withDuration: 0.3) {
                self.constraintContentHeight.constant -= (keyboardHeight)
                if distanceToKeyboard > 0 {
                    self.scrollView.contentOffset = CGPoint(x: 0, y: 0)
                }
            }
        }
        
        keyboardHeight = nil
    }

    // MARK: - Actions
    
    @IBAction func back(_ sender: UIBarButtonItem) {
        self.navigationController?.popViewController(animated: true)
    }
    
    @IBAction func finish(_ sender: UIBarButtonItem) {
        view.endEditing(false)
        activityViewContainer.isHidden = false
        firstly {
            LocalAuthenticationManager.shared.authenticate(reason: "popups.questions.restore_accounts".localized, withMainContext: true)
        }.then { result -> Promise<(Int,Int,Int,Int)> in
            guard let context = result else {
                throw RecoveryError.unauthenticated
            }
            return Seed.recover(context: context, mnemonic: self.mnemonic)
        }.ensure(on: .main) {
            self.activityViewContainer.isHidden = true
        }.done { accounts, accountsFailed, teams, teamsFailed in
            var message: String? = nil
            if accountsFailed > 0 && teamsFailed > 0 {
                message = String(format: "errors.failed_teams_and_accounts_message".localized, accountsFailed, accounts, teamsFailed, teams)
            } else if accountsFailed > 0 {
                message = String(format: "errors.failed_accounts_message".localized, accountsFailed, accounts)
            } else if teamsFailed > 0 {
                message = String(format: "errors.failed_teams_message".localized, teamsFailed, teams)
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
    
    // MARK: - Private

    private func onSeedRecoverySuccess() {
//        StoreObserver.shared.updateSubscriptions() { result in
//            if case let .failure(error) = result {
//                Logger.shared.error("Error updating subscriptions", error: error)
//            }
//            Properties.agreedWithTerms = true // If a seed is recovered, user has agreed at that time.
//            self.registerForPushNotifications()
//            Logger.shared.analytics(.backupRestored, override: true)
//        }
        Properties.agreedWithTerms = true // If a seed is recovered, user has agreed at that time.
        self.registerForPushNotifications()
        Logger.shared.analytics(.backupRestored, override: true)
    }

    private func showRootController() {
        guard let window = UIApplication.shared.keyWindow else {
            return
        }
        guard let vc = UIStoryboard.main.instantiateViewController(withIdentifier: "RootController") as? RootViewController else {
            Logger.shared.error("Unexpected root view controller type")
            fatalError("Unexpected root view controller type")
        }
        UIView.transition(with: window, duration: 0.3, options: .transitionCrossDissolve, animations: {
            DispatchQueue.main.async {
                window.rootViewController = vc
            }
        })
    }

    private func checkMnemonic() -> Bool {
        for word in mnemonic {
            if word == "" { return false }
        }
        return Seed.validate(mnemonic: mnemonic)
    }

    private func checkWord(for textField: UITextField) {
        if let word = textField.text, word != "", (wordlists.contains { $0.contains(word) }) {
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
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: { action in
            self.navigationController?.popViewController(animated: true)
        }))
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { action in
            firstly {
                BrowserSession.deleteAll()
            }.done {
                TeamSession.purgeSessionDataFromKeychain()
                UserAccount.deleteAll()
                Seed.delete()
                NotificationManager.shared.deleteEndpoint()
            }.catchLog("Error deleting data")
        }))
        self.present(alert, animated: true, completion: nil)
    }

    private func registerForPushNotifications() {
        firstly {
            PushNotifications.register()
        }.then { result -> Guarantee<Bool> in
            if result {
                return NotificationManager.shared.subscribe()
            } else {
                return .value(result)
            }
        }.done(on: DispatchQueue.main) { _ in
            self.showRootController()
        }
    }

}
