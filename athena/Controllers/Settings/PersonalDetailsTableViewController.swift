//
//  PersonalDetailsTableViewController.swift
//  athena
//
//  Created by bas on 07/01/2018.
//  Copyright © 2018 athena. All rights reserved.
//  TODO: Is this the best way to save userdata? Or in Keychain?

import UIKit

class PersonalDetailsTableViewController: UITableViewController, UITextFieldDelegate {

    let personalDetailLabels = ["First name", "Last name", "Address", "ZIP code", "City", "Country", "Phone"]
    var personalDetails = [String:String]()

    override func viewDidLoad() {
        super.viewDidLoad()
        let dict = Dictionary<String,String>
        if let defaults = UserDefaults.standard.dictionary(forKey: "personalDetails") as? [String:String] {
            personalDetails = defaults
        }

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        UserDefaults.standard.set(personalDetails, forKey: "personalDetails")
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return personalDetailLabels.count
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "PersonalDetailCell", for: indexPath) as! PersonalDetailTableViewCell

        cell.titleLabel.text = personalDetailLabels[indexPath.row]
        cell.valueTextField.text = personalDetails[personalDetailLabels[indexPath.row]]
        cell.valueTextField.delegate = self
        cell.valueTextField.addTarget(self, action: #selector(textFieldDidChange(textField:)), for: .editingChanged)

        return cell
    }


    /*
    // Override to support conditional editing of the table view.
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the specified item to be editable.
        return true
    }
    */

    /*
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            personalDetails.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
        }    
    }
    */

    /*
    // Override to support rearranging the table view.
    override func tableView(_ tableView: UITableView, moveRowAt fromIndexPath: IndexPath, to: IndexPath) {

    }
    */

    /*
    // Override to support conditional rearranging of the table view.
    override func tableView(_ tableView: UITableView, canMoveRowAt indexPath: IndexPath) -> Bool {
        // Return false if you do not want the item to be re-orderable.
        return true
    }
    */

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

    // MARK: UITextFieldDelegate

    // Hide the keyboard.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }

    @objc func textFieldDidChange(textField: UITextField){
        if let cell = textField.superview?.superview?.superview as? PersonalDetailTableViewCell, let indexPath = tableView.indexPath(for: cell) {
            personalDetails[personalDetailLabels[indexPath.row]] = textField.text
        }
    }

    // MARK: Actions

    func dismissKeyboard() {
        //Causes the view (or one of its embedded text fields) to resign the first responder status and drop into background
        view.endEditing(true)
    }

}
