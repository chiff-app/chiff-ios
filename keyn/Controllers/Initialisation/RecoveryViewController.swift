//
//  RecoveryViewController.swift
//  keyn
//
//  Created by bas on 22/12/2017.
//  Copyright © 2017 keyn. All rights reserved.
//

import UIKit

class RecoveryViewController: UIViewController, UITextFieldDelegate {
    
    var isInitialSetup = true // TODO: Implement calling recovery from settings?
    @IBOutlet var wordTextFields: Array<UITextField>?
    @IBOutlet weak var finishButton: UIButton!
    var mnemonic = Array<String>(repeating: "", count: 12) {
        didSet {
            mnemonicIsValid = checkMnemonic()
        }
    }
    var mnemonicIsValid = false {
        didSet {
            finishButton.isEnabled = mnemonicIsValid
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        for textField in wordTextFields! {
            textField.delegate = self
        }
        
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
        
        // Do any additional setup after loading the view.
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return UIStatusBarStyle.lightContent
    }
    
    private func checkMnemonic() -> Bool {
        for word in mnemonic {
            if word == "" { return false }
        }
        return Seed.validate(mnemonic: mnemonic)
    }

    //MARK: UITextFieldDelegate
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        // Hide the keyboard.
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if let index = wordTextFields?.index(of: textField) {
            mnemonic[index] = textField.text ?? ""
        }
    }
    
    @objc func dismissKeyboard() {
        view.endEditing(true)
    }
    
    // MARK: Actions
    
    @IBAction func finish(_ sender: UIButton) {
        do {
            if try Seed.recover(mnemonic: mnemonic) {
                if isInitialSetup {
                    loadRootController()
                } else {
                    self.dismiss(animated: true, completion: nil)
                }
            }
        } catch {
            print("Seed could not be recovered: \(error)")
        }
    }
    
    private func loadRootController() {
        let storyboard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let rootController = storyboard.instantiateViewController(withIdentifier: "RootController") as! RootViewController
        UIApplication.shared.keyWindow?.rootViewController = rootController
    }
    
    
    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
