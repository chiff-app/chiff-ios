//
//  BackupCheckViewController.swift
//  keyn
//
//  Created by bas on 31/12/2017.
//  Copyright © 2017 keyn. All rights reserved.
//

import UIKit
import JustLog

class BackupCheckViewController: UIViewController, UITextFieldDelegate {
    @IBOutlet weak var firstWordLabel: UILabel!
    @IBOutlet weak var secondWordLabel: UILabel!
    @IBOutlet weak var firstWordTextField: UITextField!
    @IBOutlet weak var secondWordTextField: UITextField!
    @IBOutlet weak var finishButton: UIBarButtonItem!


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

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }


    //MARK: UITextFieldDelegate

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

    @objc func dismissKeyboard() {
        view.endEditing(true)
    }


    // MARK: Actions


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

    // MARK: Private functions

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
