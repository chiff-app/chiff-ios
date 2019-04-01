/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class AccountsTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, UIScrollViewDelegate {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var tableView: UITableView!
    var unfilteredAccounts: [Account]!
    var filteredAccounts: [Account]!
//    let searchController = UISearchController(searchResultsController: nil)
    @IBOutlet weak var addAccountContainer: UIView!
    @IBOutlet weak var tableViewContainer: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()

        if let accountDict = try? Account.all(context: nil) {
            unfilteredAccounts = Array(accountDict.values)
        } else {
            unfilteredAccounts = [Account]()
        }
        filteredAccounts = unfilteredAccounts

        scrollView.delegate = self
        tableView.delegate = self
        tableView.dataSource = self

//        searchController.searchResultsUpdater = self
//        searchController.searchBar.searchBarStyle = .minimal
//        searchController.hidesNavigationBarDuringPresentation = true
//        searchController.dimsBackgroundDuringPresentation = false
        self.extendedLayoutIncludesOpaqueBars = false
        self.definesPresentationContext = true
//        navigationItem.searchController = searchController
        NotificationCenter.default.addObserver(forName: .accountAdded, object: nil, queue: OperationQueue.main, using: addAccount)
        NotificationCenter.default.addObserver(forName: .accountsLoaded, object: nil, queue: OperationQueue.main, using: loadAccounts)
        updateUi()
    }



    func scrollViewDidScroll(_ scrollView: UIScrollView) {
        (navigationController as? KeynNavigationController)?.moveAndResizeImage()
    }

    private func loadAccounts(notification: Notification) {
        DispatchQueue.main.async {
            if let accounts = notification.userInfo as? [String: Account] {
                self.unfilteredAccounts = accounts.values.sorted(by: { $0.site.name < $1.site.name })
                self.filteredAccounts = self.unfilteredAccounts
                self.tableView.reloadData()
                self.updateUi()
            }
        }
    }

    private func updateUi() {
        if let accounts = unfilteredAccounts, !accounts.isEmpty {
            tableViewContainer.isHidden = false
            addAccountContainer.isHidden = true
            view.backgroundColor = UIColor.primaryVeryLight
        } else {
            navigationItem.rightBarButtonItem = nil
            tableViewContainer.isHidden = true
            addAccountContainer.isHidden = false
            view.backgroundColor = UIColor.white
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text, !searchText.isEmpty {
            filteredAccounts = unfilteredAccounts.filter({ (account) -> Bool in
                return account.site.name.lowercased().contains(searchText.lowercased())
            }).sorted(by: { $0.site.name < $1.site.name })
        } else {
            filteredAccounts = unfilteredAccounts.sorted(by: { $0.site.name < $1.site.name })
        }
        tableView.reloadData()
    }

    // MARK: - Table view data source

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let accounts = filteredAccounts else {
            return 0
        }
        return accounts.count
    }
    
    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }
    
    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == UITableViewCell.EditingStyle.delete {
            let alert = UIAlertController(title: "popups.questions.delete_account".localized, message: nil, preferredStyle: .actionSheet)
            alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
            alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { action in
                let account = self.filteredAccounts![indexPath.row]
                self.deleteAccount(account: account, filteredIndexPath: indexPath)
            }))
            self.present(alert, animated: true, completion: nil)
        }
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath) as! AccountTableViewCell
//        cell.contentView.layoutMargins = UIEdgeInsets(top: 0, left: 20, bottom: 0, right: 20)
        let account = filteredAccounts[indexPath.row]
        cell.titleLabel.text = account.site.name
        return cell
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)

        if segue.identifier == "ShowAccount" {
            if let controller = (segue.destination.contents as? AccountViewController),
               let cell = sender as? UITableViewCell,
               let indexPath = tableView.indexPath(for: cell) {
                 controller.account = filteredAccounts[indexPath.row]
            }
        }
    }
    
    func updateAccount(account: Account) {
        if let filteredIndex = filteredAccounts.index(where: { account.id == $0.id }) {
            filteredAccounts[filteredIndex] = account
            let indexPath = IndexPath(row: filteredIndex, section: 0)
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
    }

    func addAccount(notification: Notification) {
        guard let account = notification.userInfo?["account"] as? Account else {
            Logger.shared.warning("Account was nil when trying to add it to the view.")
            return
        }
        DispatchQueue.main.async {
            self.addAccount(account: account)
        }
    }

    func addAccount(account: Account) {
        unfilteredAccounts.append(account)
        filteredAccounts.append(account)
        filteredAccounts.sort(by: { $0.site.name < $1.site.name })
        if let filteredIndex = filteredAccounts.index(where: { account.id == $0.id }) {
            let newIndexPath = IndexPath(row: filteredIndex, section: 0)
            tableView.insertRows(at: [newIndexPath], with: .automatic)
            self.updateUi()
        }
//        updateSearchResults(for: searchController)
    }

    // MARK: - Actions
    
    @IBAction func unwindToAccountOverview(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? AddAccountViewController, let account = sourceViewController.account {
            addAccount(account: account)
        } else if sender.identifier == "DeleteAccount", let sourceViewController = sender.source as? AccountViewController, let account = sourceViewController.account {
            if let index = filteredAccounts.index(where: { account.id == $0.id }) {
                let indexPath = IndexPath(row: index, section: 0)
                deleteAccount(account: account, filteredIndexPath: indexPath)
            }
        }
    }

    // MARK: - Private

    private func deleteAccount(account: Account, filteredIndexPath: IndexPath) {
        account.delete(completionHandler: { (error) in
            guard error == nil else {
                #warning("TODO: Present error")
                return
            }
            DispatchQueue.main.async {
                self.filteredAccounts.remove(at: filteredIndexPath.row)
                self.unfilteredAccounts.removeAll(where: { $0.id == account.id })
                self.tableView.deleteRows(at: [filteredIndexPath], with: .fade)
                self.updateUi()
            }
        })
    }
}
