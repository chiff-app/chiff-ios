//
//  FeedbackViewController.swift
//  keyn
//
//  Created by bas on 03/04/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UIKit

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

    @IBAction func sendFeedback(_ sender: UIBarButtonItem) {

        // Basic auth
        let username = "wanttoseelogs"
        let password = "ePcWXWA^lm;571;EmH_[wf8iB0s5,A"
        let loginString = String(format: "%@:%@", username, password)
        let loginData = loginString.data(using: .utf8)!
        let base64LoginString = loginData.base64EncodedString()

        // Data
        if let name = nameTextField.text {
            UserDefaults.standard.set(name, forKey: "name")
        }
        let debugLogUser = nameTextField.text ?? "Anonymous"
        let message = "userFeedback"
        guard let userFeedback = textView.text else {
            return
        }
        var context = ""
        context += userFeedback
        context += "Type=\(UIDevice.current.model)."
        context += "iOSVersion=\(UIDevice.current.systemVersion)."
        let postString = "user=\(debugLogUser)&message=\(message)&context=\(context)"

        // Request
        let url = URL(string: "https://log.keyn.io")!
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.httpBody = postString.data(using: .utf8)
        request.setValue("Basic \(base64LoginString)", forHTTPHeaderField: "Authorization")
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            guard error == nil, data != nil else {
                print("error=\(String(describing: error))")
                return
            }

            if let httpStatus = response as? HTTPURLResponse {
                if httpStatus.statusCode == 200 {
                    DispatchQueue.main.async {
                        self.nameTextField.text = ""
                        self.textView.text = "Feedback verstuurd. Bedankt!"
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2, execute: {
                            self.navigationController?.popViewController(animated: true)
                        })
                    }
                } else {
                    print("statusCode should be 200, but is \(httpStatus.statusCode)")
                    print("response = \(String(describing: response))")
                }
            }
        }
        task.resume()
    }

}
