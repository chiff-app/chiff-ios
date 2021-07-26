//
//  BackupCheckViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import ChiffCore
import UIKit

class BackupCheckViewController: UIViewController, UITextFieldDelegate {
    var mnemonic: [String]!
    private var firstWordIndex = 0
    private var secondWordIndex = 0
    private var keyboardHeight: CGFloat!
    private var initialContentOffset: CGPoint!

    @IBOutlet var contentView: UIView!
    @IBOutlet var finishButton: UIButton!
    @IBOutlet var firstWordLabel: UILabel!
    @IBOutlet var secondWordLabel: UILabel!
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var wordFieldStack: UIStackView!
    @IBOutlet var firstWordTextField: UITextField!
    @IBOutlet var secondWordTextField: UITextField!
    @IBOutlet var bottomConstraint: NSLayoutConstraint!

    // MARK: - UIViewControllerLifeCycle

    override func viewDidLoad() {
        super.viewDidLoad()
        initialSetup()
        Logger.shared.analytics(.backupCheckOpened)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        initialContentOffset = scrollView.contentOffset
    }

    // MARK: - InitialViewSetup

    private func initialSetup() {
        setWordsIndexes()
        setupNavigationBar()
        setKeyboardHandlers()
        initializeTextfields()
    }

    private func setWordsIndexes() {
        firstWordIndex = Int(arc4random_uniform(6))
        secondWordIndex = Int(arc4random_uniform(6)) + 6
    }

    private func initializeTextfields() {
        initialize(textfield: firstWordTextField, label: firstWordLabel, index: firstWordIndex)
        initialize(textfield: secondWordTextField, label: secondWordLabel, index: secondWordIndex)
    }

    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem?.setColor(color: .white)
    }

    func setKeyboardHandlers() {
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        view.addEndEditingTapGesture()
    }

    // MARK: - StatusBarStyle

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - UITextFieldDelegate

    func textFieldDidBeginEditing(_ textField: UITextField) {
        setScrollViewContentOffset()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        if textField == firstWordTextField {
            textField.resignFirstResponder()
            secondWordTextField.becomeFirstResponder()
        } else if isWordsMatch() {
            finish(nil)
        } else {
            view.endEditing(true)
        }
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        setInitialContentOffset()
        checkWords(for: textField)
    }

    @objc func textFieldDidChange(textField: UITextField) {
        checkWords(for: textField)
    }

    // MARK: - KeyboardAppearance

    @objc func keyboardWillShow(notification: NSNotification) {
        guard keyboardHeight == nil else {
            return
        }
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            keyboardHeight = keyboardSize.height
            setScrollViewContentOffset()
        }
    }

    private func setScrollViewContentOffset() {
        if let keyboardHeight = keyboardHeight {
            let currentContentOffset = CGPoint(x: 0, y: max(contentView.convert(finishButton.frame.origin, to: scrollView).y - (finishButton.frame.size.height * 2) - keyboardHeight, 0))
            scrollView.setContentOffset(currentContentOffset, animated: true)
        }
    }

    private func setInitialContentOffset() {
        scrollView.setContentOffset(initialContentOffset, animated: true)
    }

    // MARK: - Actions

    @IBAction func finish(_ sender: UIButton?) {
        if sender == nil {
            self.performSegue(withIdentifier: "showBackupFinish", sender: nil)
        }
        Seed.paperBackupCompleted = true
        Logger.shared.analytics(.backupCompleted)
    }

    // MARK: - Private functions

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
        finishButton.isEnabled = isWordsMatch()
    }

    private func isWordsMatch() -> Bool {
        return firstWordTextField.text == mnemonic[firstWordIndex] && secondWordTextField.text == mnemonic[secondWordIndex]
    }

    private func loadRootController() {
        guard let rootController = UIStoryboard.main.instantiateViewController(withIdentifier: "RootController") as? RootViewController else {
            Logger.shared.error("Wrong RootController type")
            return
        }
        rootController.selectedIndex = 1
        AppDelegate.shared.startupService.window?.rootViewController = rootController
    }

    private func initialize(textfield: UITextField, label: UILabel, index: Int) {
        let checkMarkImageView = UIImageView(image: UIImage(named: "checkmark_small"))
        checkMarkImageView.contentMode = UIView.ContentMode.center
        if let size = checkMarkImageView.image?.size {
            checkMarkImageView.translatesAutoresizingMaskIntoConstraints = false
            checkMarkImageView.widthAnchor.constraint(equalToConstant: size.width + 40.0).isActive = true
            checkMarkImageView.heightAnchor.constraint(equalToConstant: size.height).isActive = true
        }

        textfield.placeholder = "\(mnemonic[index].prefix(1))..."
        textfield.rightViewMode = .always
        textfield.rightView = checkMarkImageView
        textfield.rightView?.alpha = 0.0
        textfield.delegate = self
        textfield.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)

        let ordinalFormatter = NumberFormatter()
        ordinalFormatter.numberStyle = .ordinal
        let attributedText = NSMutableAttributedString(string: "\("backup.the".localized.capitalizedFirstLetter) ", attributes: [NSAttributedString.Key.font: UIFont.primaryMediumNormal!])
        attributedText.append(NSMutableAttributedString(string: ordinalFormatter.string(from: NSNumber(value: index + 1))!, attributes: [NSAttributedString.Key.font: UIFont.primaryBold!]))
        attributedText.append(NSMutableAttributedString(string: " \("backup.word_is".localized)", attributes: [NSAttributedString.Key.font: UIFont.primaryMediumNormal!]))
        label.attributedText = attributedText
    }
}
