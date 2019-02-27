/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class RecoveryViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet var wordTextFields: Array<UITextField>?
    @IBOutlet weak var wordTextFieldsStack: UIStackView!
    @IBOutlet weak var finishButton: UIBarButtonItem!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var constraintContentHeight: NSLayoutConstraint!
    
    private let lowerBoundaryOffset: CGFloat = 15
    private let keyboardHeightOffset: CGFloat = 40
    
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

    override func viewDidLoad() {
        super.viewDidLoad()
        wordTextFields?.sort(by: { $0.tag < $1.tag })
        for textField in wordTextFields! {
            textField.delegate = self
            textField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        }
        
        // Observe keyboard change
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
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
        if let index = wordTextFields?.index(of: textField) {
            mnemonic[index] = textField.text ?? ""
        }
    }

    @objc func textFieldDidChange(textField: UITextField){
        if let index = wordTextFields?.index(of: textField) {
            mnemonic[index] = textField.text ?? ""
        }
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
    
    #warning("TODO: Show a progress bar while data is being fetched remotely")
    @IBAction func finish(_ sender: UIBarButtonItem) {
        do {
            guard try Seed.recover(mnemonic: mnemonic) else {
                return
            }
            try BackupManager.shared.getBackupData() {
                DispatchQueue.main.async {
                    if self.isInitialSetup {
                        self.loadRootController()
                    } else {
                        self.dismiss(animated: true, completion: nil)
                    }
                }
            }
        } catch {
            Logger.shared.error("Seed could not be recovered", error: error)
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

}
