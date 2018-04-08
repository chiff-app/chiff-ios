import UIKit

class AccountsTableViewController: UITableViewController, UISearchResultsUpdating {

    var unfilteredAccounts = [Account]()
    var filteredAccounts: [Account]?
    let searchController = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            if let savedAccounts = try Account.all() {
                unfilteredAccounts.append(contentsOf: savedAccounts)
            } else if Properties.isDebug {
                try loadSampleData()
            }
        } catch {
            print("Account could not be fetched from keychain: \(error)")
        }

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

    func addAccount(account: Account) {
        let newIndexPath = IndexPath(row: unfilteredAccounts.count, section: 0)
        unfilteredAccounts.append(account)
        filteredAccounts = unfilteredAccounts
        tableView.insertRows(at: [newIndexPath], with: .automatic)
    }

    //MARK: Actions
    
    @IBAction func unwindToAccountOverview(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? NewAccountViewController, let account = sourceViewController.account {
            addAccount(account: account)
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

    private func loadSampleData() throws {
        let sampleUsername = "demo@keyn.io"
        var sampleSites = [Site]()

        sampleSites.append(Site.get(id: 1)!)
        sampleSites.append(Site.get(id: 2)!)
        sampleSites.append(Site.get(id: 4)!)
        //sampleSites.append(Site.get(id: 5)!)
        sampleSites.append(Site.get(id: 11)!)

        for site in sampleSites {
            let account = try Account(username: sampleUsername, site: site, passwordIndex: 0, password: nil)
            unfilteredAccounts.append(account)
        }

        unfilteredAccounts.append(try! Account(username: sampleUsername, site: Site.get(id: 0)!, password: "ExampleCustomPassword1"))
        unfilteredAccounts.append(try! Account(username: sampleUsername, site: Site.get(id: 3)!, password: "ExampleCustomPassword1"))
        unfilteredAccounts.append(try! Account(username: sampleUsername, site: Site.get(id: 6)!, password: "ExampleCustomPassword1"))
        //unfilteredAccounts.append(try! Account(username: sampleUsername, site: Site.get(id: 11)!, password: "ExampleCustomPassword1"))
        //unfilteredAccounts.append(try! Account(username: "apple@frankevers.nl", site: Site.get(id: 7)!, password: "REDACTED"))
        //unfilteredAccounts.append(try! Account(username: "thomas.bastet@gmail.com", site: Site.get(id: 8)!, password: "REDACTED"))
    }

}
