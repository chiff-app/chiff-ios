//
//  FeedbackViewController.swift
//  keyn
//
//  Created by bas on 03/04/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UIKit
import JustLog

class FeedbackViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var nameTextField: UITextField!
    @IBOutlet weak var sendButton: UIBarButtonItem!

    override func viewDidLoad() {
        super.viewDidLoad()

        textView.clipsToBounds = true
        textView.layer.cornerRadius = 5.0

        nameTextField.delegate = self
        nameTextField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)
        
        if let name = UserDefaults.standard.object(forKey: "name") as? String, !name.isEmpty {
            nameTextField.text = name
            sendButton.isEnabled = true
        }

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }

    // MARK: TextFieldDelegate

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


    // MARK: Actions
    // TODO: Change this?
    @IBAction func sendFeedback(_ sender: UIBarButtonItem) {
        // Data
        if let name = nameTextField.text {
            UserDefaults.standard.set(name, forKey: "name")
        }
        let debugLogUser = nameTextField.text ?? "Anonymous"
        guard let userFeedback = textView.text else {
            return
        }
        
        // PPD Testing mode toggle
        guard nameTextField.text != "Ppdtesting On" else {
            UserDefaults.standard.set(true, forKey: "ppdTestingMode")
            self.textView.text = "PPD Testing mode ON. Submit 'Ppdtesting Off' as name to revert to normal mode."
            return
        }
        guard nameTextField.text != "Ppdtesting Off" else {
            UserDefaults.standard.set(false, forKey: "ppdTestingMode")
            self.textView.text = "PPD Testing mode OFF"
            return
        }
        
        Logger.shared.info(userFeedback, userInfo: [
                "code": AnalyticsMessage.userFeedback.rawValue,
                "name": debugLogUser
            ])
        
        self.nameTextField.text = ""
        self.textView.text = "Feedback verstuurd. Bedankt!"
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: {
            self.navigationController?.popViewController(animated: true)
        })
        
    }

}
