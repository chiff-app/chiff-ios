/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import JustLog

class RecoveryViewController: UIViewController, UITextFieldDelegate {
    var isInitialSetup = true // TODO: Implement calling recovery from settings?
    @IBOutlet var wordTextFields: Array<UITextField>?
    @IBOutlet weak var wordTextFieldsStack: UIStackView!
    @IBOutlet weak var finishButton: UIBarButtonItem!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var constraintContentHeight: NSLayoutConstraint!
    
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
    
    var textFieldOffset: CGPoint!
    var textFieldHeight: CGFloat!
    var keyboardHeight: CGFloat!

    override func viewDidLoad() {
        super.viewDidLoad()
        wordTextFields?.sort(by: { (first, second) -> Bool in
            return first.tag < second.tag
        })
        for textField in wordTextFields! {
            textField.delegate = self
            textField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        }
        
        // Observe keyboard change
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
        
        // Do any additional setup after loading the view.
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
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            keyboardHeight = keyboardSize.height
            UIView.animate(withDuration: 0.3, animations: {
                self.constraintContentHeight.constant += (self.keyboardHeight - 40)
            })

            let distanceToKeyboard = (textFieldOffset.y + textFieldHeight) - (self.scrollView.frame.size.height - keyboardSize.height) + 15
            if distanceToKeyboard > 0 {
                UIView.animate(withDuration: 0.3, animations: {
                    self.scrollView.contentOffset = CGPoint(x: self.scrollView.frame.origin.x, y: distanceToKeyboard)
                })
            }

        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        UIView.animate(withDuration: 0.3) {
            self.constraintContentHeight.constant -= (self.keyboardHeight - 40)
            self.scrollView.contentOffset = CGPoint(x: 0, y: 0)
        }
        
        keyboardHeight = nil
    }

    // MARK: - Actions
    
    @IBAction func finish(_ sender: UIBarButtonItem) {
        // TODO: Show some progress bar or something will data is being fetched remotely
        do {
            if try Seed.recover(mnemonic: mnemonic)  {
                try BackupManager.sharedInstance.getBackupData(completionHandler: {
                    DispatchQueue.main.async {
                        if self.isInitialSetup {
                            self.loadRootController()
                        } else {
                            self.dismiss(animated: true, completion: nil)
                        }
                    }
                })

            }
        } catch {
            Logger.shared.error("Seed could not be recovered", error: error as NSError)
        }
    }
    
    // MARK: - Private

    private func loadRootController() {
        let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let rootController = storyboard.instantiateViewController(withIdentifier: "RootController") as! RootViewController
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
