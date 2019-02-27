/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

#warning("TODO: Make the feedback system prettier and more user friendly.")
class FeedbackViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var sendButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        textView.clipsToBounds = true

        nameTextField.delegate = self
        nameTextField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        
        if let name = UserDefaults.standard.object(forKey: "name") as? String, !name.isEmpty {
            nameTextField.text = name
            sendButton.isEnabled = true
        }

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }

    // MARK: - TextFieldDelegate

    func textFieldDidEndEditing(_ textField: UITextField) {
        let name = textField.text ?? ""
        if !name.isEmpty {
            sendButton.isEnabled = true
        }
    }

    @objc func textFieldDidChange(textField: UITextField){
        let name = textField.text ?? ""
        if !name.isEmpty {
            sendButton.isEnabled = true
        }
    }

    // MARK: - Actions

    #warning("TODO: Figure out if this still works.")
    @IBAction func sendFeedback(_ sender: UIBarButtonItem) {
        // Data
        if let name = nameTextField.text {
            UserDefaults.standard.set(name, forKey: "name")
        }
        let debugLogUser = nameTextField.text ?? "Anonymous"
        guard let userFeedback = textView.text else {
            return
        }

        Logger.shared.analytics(userFeedback, code: .userFeedback, userInfo: [ "name": debugLogUser ])
        
        self.nameTextField.text = ""
        self.textView.text = "settings.feedback_submitted".localized

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: {
            self.navigationController?.popViewController(animated: true)
        })
    }

}
