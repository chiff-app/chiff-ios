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
    @IBOutlet weak var finishButton: UIButton!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var constraintContentHeight: NSLayoutConstraint!
    @IBOutlet weak var bottomConstraint: NSLayoutConstraint!

    private var textFieldOffset: CGPoint!
    private var textFieldHeight: CGFloat!
    private var keyboardHeight: CGFloat!
    private let lowerBoundaryOffset: CGFloat = 109

    var mnemonic: [String]!
    private var firstWordIndex = 0
    private var secondWordIndex = 0

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        firstWordIndex = Int(arc4random_uniform(6))
        secondWordIndex = Int(arc4random_uniform(6)) + 6

        initialize(textfield: firstWordTextField, label: firstWordLabel, index: firstWordIndex)
        initialize(textfield: secondWordTextField, label: secondWordLabel, index: secondWordIndex)

        // Observe keyboard change
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))

        navigationItem.leftBarButtonItem?.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.primaryBold!], for: UIControl.State.normal)
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
        checkWords(for: textField)
    }

    @objc func textFieldDidChange(textField: UITextField){
        checkWords(for: textField)
    }
    
    @objc func keyboardWillShow(notification: NSNotification) {
        guard keyboardHeight == nil else {
            return
        }
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            let lowerBoundary = (wordFieldStack.frame.origin.y + wordFieldStack.frame.size.height) - (self.scrollView.frame.size.height - keyboardSize.height) + lowerBoundaryOffset
            if lowerBoundary > 0 {
                keyboardHeight = keyboardSize.height
                UIView.animate(withDuration: 0.3, animations: {
                    self.bottomConstraint.constant += (self.keyboardHeight)
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
            self.bottomConstraint.constant -= (self.keyboardHeight)
            self.scrollView.contentOffset = CGPoint(x: 0, y: 0)
        }
        
        keyboardHeight = nil
    }

    // MARK: - Actions

    @IBAction func finish(_ sender: UIButton) {
        do {
            try Seed.setPaperBackupCompleted()
            Logger.shared.analytics("Backup completed.", code: .backupCompleted)
        } catch {
            Logger.shared.warning("Could not set seed to backed up.", error: error)
        }
    }

    // MARK: - Private

    private func checkWords(for textField: UITextField) {
        let index = textField == firstWordTextField ? firstWordIndex : secondWordIndex
        if textField.text == mnemonic[index] {
            UIView.animate(withDuration: 0.1) {
                textField.rightView?.alpha = 1.0
            }
        } else if let alpha = textField.rightView?.alpha, alpha > 0.0 {
            UIView.animate(withDuration: 0.1) {
                textField.rightView?.alpha = 0.0
            }
        }
        finishButton.isEnabled = firstWordTextField.text == mnemonic[firstWordIndex] && secondWordTextField.text == mnemonic[secondWordIndex]
    }

    private func loadRootController() {
        let rootController = UIStoryboard.main.instantiateViewController(withIdentifier: "RootController") as! RootViewController
        rootController.selectedIndex = 1
        UIApplication.shared.keyWindow?.rootViewController = rootController
    }

    private func initialize(textfield: UITextField, label: UILabel, index: Int) {
        let checkMarkImageView = UIImageView(image: UIImage(named: "checkmark_small"))
        checkMarkImageView.contentMode = UIView.ContentMode.center
        if let size = checkMarkImageView.image?.size {
            checkMarkImageView.frame = CGRect(x: 0.0, y: 0.0, width: size.width + 40.0, height: size.height)
        }

        textfield.placeholder = "\(mnemonic[index].prefix(1))..."
        textfield.rightViewMode = .always
        textfield.rightView = checkMarkImageView
        textfield.rightView?.alpha = 0.0
        textfield.delegate = self
        textfield.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)

        let ordinalFormatter = NumberFormatter()
        ordinalFormatter.numberStyle = .ordinal
        let attributedText = NSMutableAttributedString(string: "The ", attributes: [NSAttributedString.Key.font: UIFont.primaryMediumNormal!])
        attributedText.append(NSMutableAttributedString(string: ordinalFormatter.string(from: NSNumber(value: index + 1))!, attributes: [NSAttributedString.Key.font: UIFont.primaryBold!]))
        attributedText.append(NSMutableAttributedString(string: " word is", attributes: [NSAttributedString.Key.font: UIFont.primaryMediumNormal!]))
        label.attributedText = attributedText
    }
}
