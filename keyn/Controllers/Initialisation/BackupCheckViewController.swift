/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import JustLog

class BackupCheckViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var firstWordLabel: UILabel!
    @IBOutlet weak var secondWordLabel: UILabel!
    @IBOutlet weak var firstWordTextField: UITextField!
    @IBOutlet weak var secondWordTextField: UITextField!
    @IBOutlet weak var wordFieldStack: UIStackView!
    @IBOutlet weak var finishButton: UIBarButtonItem!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var constraintContentHeight: NSLayoutConstraint!
    
    var textFieldOffset: CGPoint!
    var textFieldHeight: CGFloat!
    var keyboardHeight: CGFloat!

    var mnemonic: [String]?
    var firstWordIndex = 0
    var secondWordIndex = 0
    var isInitialSetup = true

    override func viewDidLoad() {
        super.viewDidLoad()
        firstWordIndex = Int(arc4random_uniform(5))
        secondWordIndex = Int(arc4random_uniform(5)) + 6

        firstWordLabel.text = "Word #\(firstWordIndex+1)"
        secondWordLabel.text = "Word #\(secondWordIndex+1)"
        firstWordTextField.placeholder = "\(mnemonic![firstWordIndex].prefix(3))..."
        secondWordTextField.placeholder = "\(mnemonic![secondWordIndex].prefix(3))..."

        firstWordTextField.delegate = self
        secondWordTextField.delegate = self
        firstWordTextField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        secondWordTextField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        
        // Observe keyboard change
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)

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
        checkWords()
    }

    @objc func textFieldDidChange(textField: UITextField){
        checkWords()
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard keyboardHeight == nil else {
            return
        }
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            let lowerBoundary = (wordFieldStack.frame.origin.y + wordFieldStack.frame.size.height) - (self.scrollView.frame.size.height - keyboardSize.height) + 15
            if lowerBoundary > 0 {
                keyboardHeight = keyboardSize.height
                UIView.animate(withDuration: 0.3, animations: {
                    self.constraintContentHeight.constant += (self.keyboardHeight - 40)
                })
                
                UIView.animate(withDuration: 0.3, animations: {
                    self.scrollView.contentOffset = CGPoint(x: self.scrollView.frame.origin.x, y: lowerBoundary)
                })
            }
        }
    }
    
    @objc func keyboardWillHide(notification: NSNotification) {
        guard keyboardHeight != nil else {
            return
        }
        UIView.animate(withDuration: 0.3) {
            self.constraintContentHeight.constant -= (self.keyboardHeight - 40)
            self.scrollView.contentOffset = CGPoint(x: 0, y: 0)
        }
        
        keyboardHeight = nil
    }

    // MARK: - Actions

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        if isInitialSetup {
            loadRootController()
        } else {
            dismiss(animated: true, completion: nil)
        }
    }

    @IBAction func finish(_ sender: UIBarButtonItem) {
        Logger.shared.info("Backup completed.", userInfo: ["code": AnalyticsMessage.backupCompleted.rawValue])
        do {
            try Seed.setBackedUp()
        } catch {
            Logger.shared.warning("Could not set seed to backed up.", error: error as NSError)
        }
        if isInitialSetup {
            loadRootController()
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    // MARK: - Private

    private func checkWords() {
        if (firstWordTextField.text == mnemonic![firstWordIndex] && secondWordTextField.text == mnemonic![secondWordIndex]) {
            finishButton.isEnabled = true
        } else {
            finishButton.isEnabled = false
        }
    }

    private func loadRootController() {
        let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let rootController = storyboard.instantiateViewController(withIdentifier: "RootController") as! RootViewController
        rootController.selectedIndex = 1
        UIApplication.shared.keyWindow?.rootViewController = rootController
    }
}
