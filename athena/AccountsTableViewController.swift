//
//  AccountsTableViewController.swift
//  athena
//
//  Created by bas on 03/11/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import UIKit

class AccountsTableViewController: UITableViewController {

    var accounts = [Account]()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.navigationItem.leftBarButtonItem = self.editButtonItem

        loadSampleData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accounts.count
    }


    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Account Cell", for: indexPath)

        let account = accounts[indexPath.row]
        cell.textLabel?.text = account.site.name // TODO: Change to account.siteName
        cell.detailTextLabel?.text = account.username // TODO: Change to account.userName

        return cell
    }
    
    // Override to support editing the table view.
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            accounts.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        } else if editingStyle == .insert {
            // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view
            // TODO: Check if this is more appropriate for adding a new accunt manually.
        }    
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        switch(segue.identifier ?? "") {
        case "ShowAccountDetail":
            if let accountViewController = (segue.destination.contents as? AccountViewController),
                let selectedAccountCell = sender as? UITableViewCell,
                let indexPath = tableView.indexPath(for: selectedAccountCell) {
                    accountViewController.account = accounts[indexPath.row]
            }
        case "AddAccount":
            if let accountViewController = (segue.destination.contents as? AccountViewController) {
                print("TODO: add account VC")
            }
        default:
            fatalError("Unexpected Segue Identifier; \(String(describing: segue.identifier))")
        }
    }


    // MARK: Temporary sample data

    private func loadSampleData() {
        let sampleUsername = "athenademo@protonmail.com"
        var sampleSites = [Site]()
        sampleSites.append(Site(name: "LinkedIn", id: "0", urls: ["https://www.linkedin.com"]))
        sampleSites.append(Site(name: "Gmail", id: "1", urls: ["https://gmail.com/login"]))
        sampleSites.append(Site(name: "ProtonMail", id: "2", urls: ["https://mail.protonmail.com/login"]))
        sampleSites.append(Site(name: "University of London", id: "3", urls: ["https://my.londoninternational.ac.uk/login"]))
        sampleSites.append(Site(name: "Github", id: "4", urls: ["https://github.com/login"]))
        sampleSites.append(Site(name: "DigitalOcean", id: "5", urls: ["https://cloud.digitalocean.com/login"]))
        for site in sampleSites {
            let account = Account(username: sampleUsername, site: site, passwordIndex: "0")
            accounts.append(account)
        }
    }

}

extension UIViewController {
    var contents: UIViewController {
        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController ?? self
        } else {
            return self
        }
    }

}
