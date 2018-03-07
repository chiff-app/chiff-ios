import UIKit

class AccountsTableViewController: UITableViewController, UISearchResultsUpdating {

    var unfilteredAccounts = [Account]()
    var filteredAccounts: [Account]?
    let searchController = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad()
        //self.navigationItem.leftBarButtonItem = self.editButtonItem
        loadSampleData()
        filteredAccounts = unfilteredAccounts
        searchController.searchResultsUpdater = self
        searchController.searchBar.searchBarStyle = .minimal
        searchController.hidesNavigationBarDuringPresentation = true
        searchController.dimsBackgroundDuringPresentation = false
        self.extendedLayoutIncludesOpaqueBars = false
        self.definesPresentationContext = true
        navigationItem.searchController = searchController
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        if let navigationView = navigationController?.view {
            fixShadowImage(inView: navigationView)
        }
    }
    
    // This fixes the navigationBar.shadowImage bug: https://forums.developer.apple.com/message/259206#259206
    func fixShadowImage(inView view: UIView) {
        if let imageView = view as? UIImageView {
            let size = imageView.bounds.size.height
            if size <= 1 && size > 0 &&
                imageView.subviews.count == 0,
                let components = imageView.backgroundColor?.cgColor.components, components == [0.0, 0.0, 0.0, 0.3]
            {
                let line = UIView(frame: CGRect(x: 0, y: 0, width: UIScreen.main.bounds.width, height: 2))
                line.backgroundColor = UIColor(rgb: 0x4932A2)
                imageView.addSubview(line)
                line.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            }
        }
        for subview in view.subviews {
            fixShadowImage(inView: subview)
        }
    }
    
    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text, !searchText.isEmpty {
            filteredAccounts = unfilteredAccounts.filter({ (account) -> Bool in
                return account.site.name.lowercased().contains(searchText.lowercased())
            })
        } else {
            filteredAccounts = unfilteredAccounts
        }
        tableView.reloadData()
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
    }

    // MARK: - Table view data source

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let accounts = filteredAccounts else {
            return 0
        }
        return accounts.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath)

        if let accounts = filteredAccounts {
            let account = accounts[indexPath.row]
            cell.textLabel?.text = account.site.name
            cell.detailTextLabel?.text = account.username
        }
        return cell
    }
    
//    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
//        if editingStyle == .delete {
//            // Delete the row from the data source
//            do {
//                let account = accounts.remove(at: indexPath.row)
//                try account.delete()
//                tableView.deleteRows(at: [indexPath], with: .fade)
//            } catch {
//                print("Account could not be deleted: \(error)")
//            }
//        }
//    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if segue.identifier == "ShowAccount" {
            if let controller = (segue.destination.contents as? AccountViewController),
               let cell = sender as? UITableViewCell,
               let indexPath = tableView.indexPath(for: cell) {
                 controller.account = unfilteredAccounts[indexPath.row]
            }
        }
    }

    //MARK: Actions
    
    @IBAction func unwindToAccountOverview(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? NewAccountViewController, let account = sourceViewController.account {
            
            let newIndexPath = IndexPath(row: unfilteredAccounts.count, section: 0)
            
            unfilteredAccounts.append(account)
            filteredAccounts = unfilteredAccounts
            tableView.insertRows(at: [newIndexPath], with: .automatic)
        } else if let sourceViewController = sender.source as? AccountViewController, let account = sourceViewController.account {
            if let index = unfilteredAccounts.index(where: { (unfilteredAccount) -> Bool in
                return account.id == unfilteredAccount.id
            }) {
                let indexPath = IndexPath(row: index, section: 0)
                do {
                    try account.delete()
                    unfilteredAccounts.remove(at: index)
                    filteredAccounts = unfilteredAccounts
                    tableView.deleteRows(at: [indexPath], with: .automatic)
                } catch {
                    print("Account could not be deleted: \(error)")
                }
            }
        }
    }

    // MARK: Temporary sample data

    private func loadSampleData() {
        // try loading persistent data:
        do {
            if let savedAccounts = try Account.all() {
                print("Loading accounts from keychain.")
                unfilteredAccounts.append(contentsOf: savedAccounts)
            } else {
                let sampleUsername = "athenademo@protonmail.com"
                var sampleSites = [Site]()
                
                let restrictions = PasswordRestrictions(length: 24, characters: [.lower, .numbers, .upper, .symbols])
                
                sampleSites.append(Site(name: "LinkedIn", id: "0", urls: ["https://www.linkedin.com"], restrictions: PasswordRestrictions(length: 30, characters: [.lower, .numbers, .upper, .symbols])))
                sampleSites.append(Site(name: "Gmail", id: "1", urls: ["https://gmail.com/login"], restrictions: restrictions))
                sampleSites.append(Site(name: "ProtonMail", id: "2", urls: ["https://mail.protonmail.com/login"], restrictions: restrictions))
                sampleSites.append(Site(name: "University of London", id: "3", urls: ["https://my.londoninternational.ac.uk/login"], restrictions: restrictions))
                sampleSites.append(Site(name: "Github", id: "4", urls: ["https://github.com/login"], restrictions: restrictions))
                
                for site in sampleSites {
                    let account = try! Account(username: sampleUsername, site: site, passwordIndex: 2, password: nil)
                    unfilteredAccounts.append(account)
                }

                let customSite = Site(name: "DigitalOcean", id: "5", urls: ["https://cloud.digitalocean.com/login"], restrictions: restrictions)
                unfilteredAccounts.append(try! Account(username: sampleUsername, site: customSite, password: "ExampleCustomPassword"))
                
            }
        } catch {
            print("Account could not be fetched from keychain: \(error)")
        }

    }

}

