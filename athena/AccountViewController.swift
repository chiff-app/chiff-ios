//
//  AccountViewController.swift
//  athena
//
//  Created by bas on 03/11/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import UIKit

class AccountViewController: UITableViewController {

    @IBOutlet weak var websiteNameCell: UITableViewCell!
    @IBOutlet weak var websiteURLcell: UITableViewCell!
    @IBOutlet weak var userNameCell: UITableViewCell!
    @IBOutlet weak var userPasswordCell: UITableViewCell!

    override func viewDidLoad() {
        super.viewDidLoad()
        // Uncomment the following line to preserve selection between presentations
        // self.clearsSelectionOnViewWillAppear = false

        // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
        // self.navigationItem.rightBarButtonItem = self.editButtonItem
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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
