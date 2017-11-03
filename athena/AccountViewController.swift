//
//  AccountViewController.swift
//  athena
//
//  Created by bas on 03/11/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import UIKit
import MBProgressHUD

class AccountViewController: UITableViewController {

    //MARK: Properties

    var account: Account?
    @IBOutlet weak var websiteNameTextField: UITextField!
    @IBOutlet weak var websiteURLTextField: UITextField!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var userPasswordTextField: UITextField!

    override func viewDidLoad() {
        super.viewDidLoad()

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem

        if let account = account {
            websiteNameTextField.text = account.site.name
            websiteURLTextField.text = account.site.urls[0]
            userNameTextField.text = account.username
            userPasswordTextField.text = account.password()
        }
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: Actions
    @IBAction func showPassword(_ sender: UIButton) {
        if account != nil {
            let showPasswordHUD = MBProgressHUD.showAdded(to: self.view, animated: true)
            showPasswordHUD.mode = .text
            showPasswordHUD.label.text = userPasswordTextField.text
            showPasswordHUD.label.textColor = .black
            showPasswordHUD.label.font = UIFont(name: "Courier New", size: 24)
            showPasswordHUD.margin = 10
            showPasswordHUD.label.numberOfLines = 0
            showPasswordHUD.removeFromSuperViewOnHide = true
            showPasswordHUD.addGestureRecognizer(
                UITapGestureRecognizer(
                    target: showPasswordHUD,
                    action: #selector(showPasswordHUD.hide(animated:)))
            )
        }
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
