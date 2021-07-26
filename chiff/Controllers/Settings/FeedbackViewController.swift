//
//  FeedbackViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import ChiffCore
import PromiseKit
import UIKit

class FeedbackViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {
    private var keyboardHeight: CGFloat!
    private var initialContentOffset: CGPoint!

    @IBOutlet var contentView: UIView!
    @IBOutlet var textView: UITextView!
    @IBOutlet var scrollView: UIScrollView!
    @IBOutlet var nameTextField: UITextField!
    @IBOutlet var sendButton: UIBarButtonItem!

    // MARK: - UIViewControllerLifeCycle

    override func viewDidLoad() {
        super.viewDidLoad()
        initialSetup()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        initialContentOffset = scrollView.contentOffset
    }

    // MARK: - InitialViewSetup

    private func initialSetup() {
        setupImputFields()
        setKeyboardHandlers()
        setupNavigationBar()
    }

    private func setupNavigationBar() {
        navigationItem.leftBarButtonItem?.setColor(color: .white)
        navigationItem.rightBarButtonItem?.setColor(color: .white)
    }

    private func setupImputFields() {
        textView.clipsToBounds = true
        textView.layer.cornerRadius = 4.0
        nameTextField.layer.cornerRadius = 4.0
        nameTextField.delegate = self
        textView.delegate = self
        nameTextField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        if let name = UserDefaults.standard.object(forKey: "name") as? String, !name.isEmpty {
            nameTextField.text = name
            sendButton.isEnabled = true
        }
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

    // MARK: - TextFieldDelegate

    func textFieldDidBeginEditing(_ textField: UITextField) {
        setScrollViewContentOffsetFor(textField)
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        let name = textField.text ?? ""
        if !name.isEmpty {
            sendButton.isEnabled = true
        }
        setInitialContentOffset()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textView.becomeFirstResponder()
        return true
    }

    @objc private func textFieldDidChange(textField: UITextField) {
        let name = textField.text ?? "anonymous"
        if !name.isEmpty {
            sendButton.isEnabled = true
        }
    }

    // MARK: - TextViewDelegate

    func textViewDidBeginEditing(_ textView: UITextView) {
        setScrollViewContentOffsetFor(textView)
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        setInitialContentOffset()
    }

    // MARK: - KeyboardAppearance

    @objc func keyboardWillShow(notification: NSNotification) {
        guard keyboardHeight == nil else {
            return
        }
        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            keyboardHeight = keyboardSize.height + view.safeAreaInsets.bottom
        }
        if let view = view.firstResponder {
            setScrollViewContentOffsetFor(view)
        }
    }

    private func setScrollViewContentOffsetFor(_ view: UIView) {
        if let keyboardHeight = keyboardHeight {
            let currentContentOffset = CGPoint(x: 0, y: max(contentView.convert(view.superview!.frame.origin, to: scrollView).y + (view.frame.size.height / 1.4) - keyboardHeight, 0))
            scrollView.setContentOffset(currentContentOffset, animated: true)
        }
    }

    private func setInitialContentOffset() {
        scrollView.setContentOffset(initialContentOffset, animated: true)
    }

    // MARK: - Actions

    @IBAction func sendFeedback(_ sender: UIBarButtonItem) {
        // Data
        if let name = nameTextField.text {
            UserDefaults.standard.set(name, forKey: "name")
        }
        let debugLogUser = nameTextField.text ?? "Anonymous"
        guard let userFeedback = textView.text else {
            return
        }
        let message = """
        Hallo met \(debugLogUser),


        Allereerst grote complimenten voor het ontwikkelen van deze fantastische app. Hulde! Ik kwam alleen het volgende tegen:

        \(userFeedback)

        Groetjes,

        \(debugLogUser)
        id: \(Properties.userId ?? "not set")
        """
        firstly {
            API.shared.request(path: "analytics", method: .post, body: message.data)
        }.ensure {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.dismiss(animated: true, completion: nil)
            }
        }.done(on: .main) { _ in
            self.nameTextField.text = ""
            self.textView.text = "settings.feedback_submitted".localized
        }.catchLog("Error posting feedback")
    }
}
