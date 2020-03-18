/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import PromiseKit

class FeedbackViewController: UIViewController, UITextFieldDelegate, UITextViewDelegate {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var sendButton: UIBarButtonItem!

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var constraintContentHeight: NSLayoutConstraint! // Should be raised to 1000 on keyboard show
    @IBOutlet weak var bottomDistanceConstraint: NSLayoutConstraint!

    private let FRAME_HEIGHT: CGFloat = 480
    private let HEIGHT_OFFSET: CGFloat = 68
    private let BOTTOM_OFFSET: CGFloat = 10
    private var lastOffset: CGPoint!
    private var keyboardHeight: CGFloat!

    override func viewDidLoad() {
        super.viewDidLoad()
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

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))

        self.constraintContentHeight.constant = self.view.frame.size.height - HEIGHT_OFFSET

        navigationItem.leftBarButtonItem?.setColor(color: .white)
        navigationItem.rightBarButtonItem?.setColor(color: .white)

        view.layoutIfNeeded()
        textView.layer.cornerRadius = 4.0

        // Observe keyboard change
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)

    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    // MARK: - TextFieldDelegate

    func textFieldDidEndEditing(_ textField: UITextField) {
        let name = textField.text ?? ""
        if !name.isEmpty {
            sendButton.isEnabled = true
        }
    }

    @objc private func textFieldDidChange(textField: UITextField){
        let name = textField.text ?? "anonymous"
        if !name.isEmpty {
            sendButton.isEnabled = true
        }
    }

    func textFieldShouldBeginEditing(_ textField: UITextField) -> Bool {
        lastOffset = self.scrollView.contentOffset
        return true
    }

    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        lastOffset = self.scrollView.contentOffset
        return true
    }

    func textFieldShouldEndEditing(_ textField: UITextField) -> Bool {
        return true
    }

    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        return true
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        guard keyboardHeight == nil else {
            return
        }

        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            keyboardHeight = keyboardSize.height
            // so increase contentView's height by keyboard height
            UIView.animate(withDuration: 0.3, animations: {
                self.bottomDistanceConstraint.constant += (self.keyboardHeight)
                self.constraintContentHeight.constant += (self.keyboardHeight)
            })

            let distanceToBottom = self.scrollView.frame.size.height - (textView.frame.origin.y) - (textView.frame.size.height)

            // set new offset for scroll view
            UIView.animate(withDuration: 0.3, animations: {
                // scroll to the position above bottom 10 points
                self.scrollView.contentOffset = CGPoint(x: self.lastOffset.x, y: distanceToBottom + self.BOTTOM_OFFSET)
            })
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        guard keyboardHeight != nil else {
            return
        }

        UIView.animate(withDuration: 0.3) {
            self.bottomDistanceConstraint.constant -= (self.keyboardHeight)
            self.constraintContentHeight.constant -= (self.keyboardHeight)
            self.scrollView.contentOffset = self.lastOffset
        }

        keyboardHeight = nil
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
            API.shared.request(path: "analytics", parameters: nil, method: .put, signature: nil, body: message.data)
        }.ensure {
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0, execute: {
                self.dismiss(animated: true, completion: nil)
            })
        }.done(on: .main) { _ in
            self.nameTextField.text = ""
            self.textView.text = "settings.feedback_submitted".localized
        }.catchLog("Error posting feedback")
    }

}
