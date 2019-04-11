/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

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
    private var keyboardHeight: CGFloat!
    
    var mnemonic = Array<String>(repeating: "", count: 12) {
        didSet {
            mnemonicIsValid = checkMnemonic()
        }
    }
    var mnemonicIsValid = false {
        didSet {
            finishButton.isEnabled = mnemonicIsValid
        }
    }

    var isInitialSetup = true
    let wordlist = try! Seed.wordlist()

    override func viewDidLoad() {
        super.viewDidLoad()
        wordTextFields?.sort(by: { $0.tag < $1.tag })
        for textField in wordTextFields! {
            initialize(textfield: textField)
        }

        // Observe keyboard change
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))

        navigationItem.rightBarButtonItem?.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.primaryBold!], for: UIControl.State.normal)
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([.foregroundColor: UIColor.init(white: 1, alpha: 0.5), .font: UIFont.primaryBold!], for: UIControl.State.disabled)
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
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard keyboardHeight == nil else {
            return
        }

        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            keyboardHeight = keyboardSize.height - keyboardHeightOffset
            UIView.animate(withDuration: 0.3, animations: {
                self.constraintContentHeight.constant += (self.keyboardHeight)
            })

            let distanceToKeyboard = (textFieldOffset.y + textFieldHeight) - (self.scrollView.frame.size.height - keyboardSize.height) + lowerBoundaryOffset
            if distanceToKeyboard > 0 {
                UIView.animate(withDuration: 0.3, animations: {
                    self.scrollView.contentOffset = CGPoint(x: self.scrollView.frame.origin.x, y: distanceToKeyboard)
                })
            }

        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        UIView.animate(withDuration: 0.3) {
            self.constraintContentHeight.constant -= (self.keyboardHeight)
            self.scrollView.contentOffset = CGPoint(x: 0, y: 0)
        }
        
        keyboardHeight = nil
    }

    // MARK: - Actions
    
    @IBAction func finish(_ sender: UIBarButtonItem) {
        view.endEditing(false)
        activityViewContainer.isHidden = false
        LocalAuthenticationManager.shared.unlock(reason: "popups.questions.restore_accounts".localized) { (result, error) in
            do {
                if let error = error {
                    throw error
                } else if result {
                    try Seed.recover(mnemonic: self.mnemonic)
                    try BackupManager.shared.getBackupData() {
                        DispatchQueue.main.async {
                            self.loadRootController()
                        }
                    }
                } else {
                    throw RecoveryError.unauthenticated
                }
            } catch {
                DispatchQueue.main.async {
                    self.activityViewContainer.isHidden = true
                }
                Logger.shared.error("Seed could not be recovered", error: error)
            }

        }
    }
    
    // MARK: - Private

    private func loadRootController() {
        let rootController = UIStoryboard.main.instantiateViewController(withIdentifier: "RootController") as! RootViewController
        rootController.selectedIndex = 0
        UIApplication.shared.keyWindow?.rootViewController = rootController
    }

    private func checkMnemonic() -> Bool {
        for word in mnemonic {
            if word == "" { return false }
        }
        return Seed.validate(mnemonic: mnemonic)
    }

    private func checkWord(for textField: UITextField) {
        if let word = textField.text, word != "", wordlist.contains(word) {
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
            checkMarkImageView.frame = CGRect(x: 0.0, y: 0.0, width: size.width + 40.0, height: size.height)
        }

        textfield.rightViewMode = .always
        textfield.rightView = checkMarkImageView
        textfield.rightView?.alpha = 0.0
        textfield.delegate = self
        textfield.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
    }

}
