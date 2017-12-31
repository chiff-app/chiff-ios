//
//  BackupCheckViewController.swift
//  athena
//
//  Created by bas on 31/12/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import UIKit

class BackupCheckViewController: UIViewController, UITextFieldDelegate {

    @IBOutlet weak var firstWordLabel: UILabel!
    @IBOutlet weak var secondWordLabel: UILabel!
    @IBOutlet weak var firstWordTextField: UITextField!
    @IBOutlet weak var secondWordTextField: UITextField!
    @IBOutlet weak var finishButton: UIButton!

    var mnemonic: [String]?
    var firstWordIndex = 0
    var secondWordIndex = 0

    override func viewDidLoad() {
        super.viewDidLoad()
        firstWordIndex = Int(arc4random_uniform(11))
        secondWordIndex = Int(arc4random_uniform(11))
        while secondWordIndex == firstWordIndex {
            secondWordIndex = Int(arc4random_uniform(11))
        }

        firstWordLabel.text = "Word #\(firstWordIndex+1)"
        secondWordLabel.text = "Word #\(secondWordIndex+1)"

        firstWordTextField.delegate = self
        secondWordTextField.delegate = self

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))

    }

    //MARK: UITextFieldDelegate

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard.
        textField.resignFirstResponder()
        return true
    }

    func textFieldDidEndEditing(_ textField: UITextField) {
        if (firstWordTextField.text == mnemonic![firstWordIndex] && secondWordTextField.text == mnemonic![secondWordIndex]) {
            finishButton.isEnabled = true
        } else {
            finishButton.isEnabled = false
        }
    }

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }


    @IBAction func finish(_ sender: UIButton) {

        do {
            try Seed.setBackedUp()
        } catch {
            print("Keychain couldn't be updated: \(error)")
        }

        let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let rootController = storyboard.instantiateViewController(withIdentifier: "RootController") as! RootViewController
        UIApplication.shared.keyWindow?.rootViewController = rootController
    }

}
