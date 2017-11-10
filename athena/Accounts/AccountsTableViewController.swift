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
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return accounts.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath)

        let account = accounts[indexPath.row]
        cell.textLabel?.text = account.site.name
        cell.detailTextLabel?.text = account.username

        return cell
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            // Delete the row from the data source
            accounts.remove(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .fade)
        }     
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if segue.identifier == "ShowAccount" {
            if let controller = (segue.destination.contents as? AccountViewController),
               let cell = sender as? UITableViewCell,
               let indexPath = tableView.indexPath(for: cell) {
                 controller.account = accounts[indexPath.row]
            }
        }
    }

    //MARK: Actions
    
    @IBAction func unwindToAccountOverview(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? NewAccountViewController, let account = sourceViewController.account {
            
            let newIndexPath = IndexPath(row: accounts.count, section: 0)
            
            accounts.append(account)
            tableView.insertRows(at: [newIndexPath], with: .automatic)
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
            let account = Account(username: sampleUsername, site: site, passwordIndex: 0)
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
