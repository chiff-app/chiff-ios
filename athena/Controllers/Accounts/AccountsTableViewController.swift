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
            do {
                let account = accounts.remove(at: indexPath.row)
                try account.delete()
                tableView.deleteRows(at: [indexPath], with: .fade)
            } catch {
                print("Account could not be deleted: \(error)")
            }
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
        // try loading persistent data:
        do {
            if let savedAccounts = try Account.all() {
                print("Loading accounts from keychain.")
                accounts.append(contentsOf: savedAccounts)
            } else {
                let sampleUsername = "athenademo@protonmail.com"
                var sampleSites = [Site]()
                
                let restrictions = PasswordRestrictions(length: 24, characters: [.lower, .numbers, .upper, .symbols])
                
                sampleSites.append(Site(name: "LinkedIn", id: "0", urls: ["https://www.linkedin.com"], restrictions: restrictions))
                sampleSites.append(Site(name: "Gmail", id: "1", urls: ["https://gmail.com/login"], restrictions: restrictions))
                sampleSites.append(Site(name: "ProtonMail", id: "2", urls: ["https://mail.protonmail.com/login"], restrictions: restrictions))
                sampleSites.append(Site(name: "University of London", id: "3", urls: ["https://my.londoninternational.ac.uk/login"], restrictions: restrictions))
                sampleSites.append(Site(name: "Github", id: "4", urls: ["https://github.com/login"], restrictions: restrictions))
                sampleSites.append(Site(name: "DigitalOcean", id: "5", urls: ["https://cloud.digitalocean.com/login"], restrictions: restrictions))
                
                for site in sampleSites {
                    let account = try! Account(username: sampleUsername, site: site, restrictions: nil)
                    accounts.append(account)
                }
            }
        } catch {
            print("Account could not be fetched from keychain: \(error)")
        }

    }

}

