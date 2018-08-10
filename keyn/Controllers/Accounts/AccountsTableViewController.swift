import UIKit
import JustLog

class AccountsTableViewController: UITableViewController, UISearchResultsUpdating {

    var unfilteredAccounts = [Account]()
    var filteredAccounts: [Account]?
    let searchController = UISearchController(searchResultsController: nil)

    override func viewDidLoad() {
        super.viewDidLoad()

        do {
            if let savedAccounts = try Account.all() {
                unfilteredAccounts.append(contentsOf: savedAccounts)
            }
        } catch {
            Logger.shared.error("Could not get accounts from Keychain", error: error as NSError)
        }

        filteredAccounts = unfilteredAccounts.sorted(by: { (first, second) -> Bool in
            first.site.name < second.site.name
        })
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
            }).sorted(by: { (first, second) -> Bool in
                first.site.name < second.site.name
            })
        } else {
            filteredAccounts = unfilteredAccounts.sorted(by: { (first, second) -> Bool in
                first.site.name < second.site.name
            })
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
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCellEditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCellEditingStyle.delete {
            let alert = UIAlertController(title: "Delete account?", message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
                let account = self.filteredAccounts![indexPath.row]
                self.deleteAccount(account: account, filteredIndexPath: indexPath)
            }))
            self.present(alert, animated: true, completion: nil)
        }
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
                 controller.account = filteredAccounts![indexPath.row]
            }
        }
    }

    func addAccount(account: Account) {
        let newIndexPath = IndexPath(row: unfilteredAccounts.count, section: 0)
        unfilteredAccounts.append(account)
        filteredAccounts = unfilteredAccounts.sorted(by: { (first, second) -> Bool in
            first.site.name < second.site.name
        })
        tableView.insertRows(at: [newIndexPath], with: .automatic)
    }

    //MARK: Actions
    
    @IBAction func unwindToAccountOverview(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? NewAccountViewController, let account = sourceViewController.account {
            addAccount(account: account)
        } else if let sourceViewController = sender.source as? AccountViewController, let account = sourceViewController.account {
            if let index = filteredAccounts!.index(where: { (filteredAccount) -> Bool in
                return account.id == filteredAccount.id
            }) {
                let indexPath = IndexPath(row: index, section: 0)
                deleteAccount(account: account, filteredIndexPath: indexPath)
            }
        }
    }
    
    private func deleteAccount(account: Account, filteredIndexPath: IndexPath) {
        if let index = unfilteredAccounts.index(where: { (unfilteredAccount) -> Bool in
            return account.id == unfilteredAccount.id
        }) {
            do {
                try account.delete()
                unfilteredAccounts.remove(at: index)
                filteredAccounts?.remove(at: filteredIndexPath.row)
                tableView.deleteRows(at: [filteredIndexPath], with: .automatic)
            } catch {
                Logger.shared.error("Could not delete account.", error: error as NSError)
            }
        }
    }

}
