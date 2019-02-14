/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

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
    
    private var textFieldOffset: CGPoint!
    private var textFieldHeight: CGFloat!
    private var keyboardHeight: CGFloat!
    private let lowerBoundaryOffset: CGFloat = 15
    private let keyboardHeightOffset: CGFloat = 40

    var mnemonic: [String]!
    var isInitialSetup = true
    private var firstWordIndex = 0
    private var secondWordIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        firstWordIndex = Int(arc4random_uniform(5))
        secondWordIndex = Int(arc4random_uniform(5)) + 6

        firstWordLabel.text = "\("word".localized.capitalized) #\(firstWordIndex+1)"
        secondWordLabel.text = "\("word".localized.capitalized) #\(secondWordIndex+1)"
        firstWordTextField.placeholder = "\(mnemonic[firstWordIndex].prefix(3))..."
        secondWordTextField.placeholder = "\(mnemonic[secondWordIndex].prefix(3))..."

        firstWordTextField.delegate = self
        secondWordTextField.delegate = self
        firstWordTextField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        secondWordTextField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        
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
        checkWords()
    }

    @objc func textFieldDidChange(textField: UITextField){
        checkWords()
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard keyboardHeight == nil else {
            return
        }
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            let lowerBoundary = (wordFieldStack.frame.origin.y + wordFieldStack.frame.size.height) - (self.scrollView.frame.size.height - keyboardSize.height) + lowerBoundaryOffset
            if lowerBoundary > 0 {
                keyboardHeight = keyboardSize.height - keyboardHeightOffset
                UIView.animate(withDuration: 0.3, animations: {
                    self.constraintContentHeight.constant += (self.keyboardHeight)
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
            self.constraintContentHeight.constant -= (self.keyboardHeight)
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
        Logger.shared.analytics("Backup completed.", code: .backupCompleted)
        do {
            try Seed.setBackedUp()
        } catch {
            Logger.shared.warning("Could not set seed to backed up.", error: error)
        }
        if isInitialSetup {
            loadRootController()
        } else {
            self.dismiss(animated: true, completion: nil)
        }
    }

    // MARK: - Private

    private func checkWords() {
        if (firstWordTextField.text == mnemonic[firstWordIndex] && secondWordTextField.text == mnemonic[secondWordIndex]) {
            finishButton.isEnabled = true
        } else {
            finishButton.isEnabled = false
        }
    }

    private func loadRootController() {
        let rootController = UIStoryboard.main.instantiateViewController(withIdentifier: "RootController") as! RootViewController
        rootController.selectedIndex = 1
        UIApplication.shared.keyWindow?.rootViewController = rootController
    }
}
