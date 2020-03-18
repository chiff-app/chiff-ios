/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import PromiseKit

class AccountsTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UISearchResultsUpdating, UIScrollViewDelegate {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var tableView: UITableView!
    var unfilteredAccounts: [Account]!
    var filteredAccounts: [Account]!
//    let searchController = UISearchController(searchResultsController: nil)
    @IBOutlet weak var tableViewContainer: UIView!
    @IBOutlet weak var addAccountContainerView: UIView!
    @IBOutlet weak var tableViewFooter: UILabel!
    @IBOutlet weak var loadingSpinner: UIActivityIndicatorView!
    @IBOutlet weak var upgradeButton: KeynButton!
    @IBOutlet weak var upgradeButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomMarginConstraint: NSLayoutConstraint!

    var addAccountButton: KeynBarButton?

    override func viewDidLoad() {
        super.viewDidLoad()

        if let accountDict = try? UserAccount.all(context: nil) {
            unfilteredAccounts = Array(accountDict.values).sorted(by: { $0.site.name.lowercased() < $1.site.name.lowercased() })
        } else {
            unfilteredAccounts = [UserAccount]()
        }
        filteredAccounts = unfilteredAccounts
        updateUi()

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
        NotificationCenter.default.addObserver(forName: .accountsLoaded, object: nil, queue: OperationQueue.main, using: loadAccounts)
        NotificationCenter.default.addObserver(forName: .sharedAccountsChanged, object: nil, queue: OperationQueue.main, using: loadAccounts)
        NotificationCenter.default.addObserver(forName: .accountUpdated, object: nil, queue: OperationQueue.main, using: updateAccount)
        NotificationCenter.default.addObserver(forName: .subscriptionUpdated, object: nil, queue: OperationQueue.main, using: updateSubscriptionStatus)

        setFooter()
    }

    @objc func showAddAccount() {
        performSegue(withIdentifier: "ShowAddAccount", sender: self)
    }

    @objc func showAddSubscription() {
        performSegue(withIdentifier: "ShowAddSubscription", sender: self)
    }

    private func loadAccounts(notification: Notification) {
        DispatchQueue.main.async {
            if let accounts = try? notification.userInfo as? [String: Account] ?? UserAccount.allCombined(context: nil) {
                self.unfilteredAccounts = accounts.values.sorted(by: { $0.site.name.lowercased() < $1.site.name.lowercased() })
                self.filteredAccounts = self.unfilteredAccounts
                self.tableView.reloadData()
                self.updateUi()
            }
        }
    }

    private func updateUi() {
        loadingSpinner.stopAnimating()
        if let accounts = filteredAccounts, !accounts.isEmpty {
            tableViewContainer.isHidden = false
            addAccountContainerView.isHidden = true
            addAddButton(enabled: Properties.hasValidSubscription || accounts.count < Properties.accountCap)
            setFooter()
            upgradeButton.isHidden = Properties.hasValidSubscription
            upgradeButtonHeightConstraint.constant = Properties.hasValidSubscription ? 0 : 44
            bottomMarginConstraint.constant = Properties.hasValidSubscription ? 0 : 38
        } else {
            navigationItem.rightBarButtonItem = nil
            tableViewContainer.isHidden = true
            addAccountContainerView.isHidden = false
        }
    }

    private func updateSubscriptionStatus(notification: Notification) {
        DispatchQueue.main.async {
            self.filteredAccounts = self.unfilteredAccounts
            self.tableView.reloadData()
            self.setFooter()
            self.updateUi()
        }
    }

    private func setFooter() {
        if Properties.hasValidSubscription {
            tableViewFooter.text = "accounts.footer_unlimited".localized
        } else {
            tableViewFooter.text = Properties.accountOverflow ? "accounts.footer_account_overflow".localized : "accounts.footer".localized
        }
    }

    func updateSearchResults(for searchController: UISearchController) {
        if let searchText = searchController.searchBar.text, !searchText.isEmpty {
            filteredAccounts = unfilteredAccounts.filter({ (account) -> Bool in
                return account.site.name.lowercased().contains(searchText.lowercased())
            }).sorted(by: { $0.site.name.lowercased() < $1.site.name.lowercased() })
        } else {
            filteredAccounts = unfilteredAccounts.sorted(by: { $0.site.name.lowercased() < $1.site.name.lowercased() })
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
        let account = filteredAccounts[indexPath.row]
        return account is UserAccount
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
        return tableView.dequeueReusableCell(withIdentifier: "AccountCell", for: indexPath) as! AccountTableViewCell
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let cell = cell as? AccountTableViewCell {
            let account = filteredAccounts[indexPath.row]
            cell.titleLabel.text = account.site.name
            let showEnabled = account.enabled || Properties.hasValidSubscription || filteredAccounts.count <= Properties.accountCap
            cell.titleLabel.alpha = showEnabled ? 1 : 0.5
            cell.icon.alpha = showEnabled ? 1 : 0.5
            cell.teamIconWidthConstraint.constant = account is SharedAccount ? 24 : 0
            if #available(iOS 13.0, *) {
                cell.teamIcon.image = UIImage(systemName: "person.2.fill")
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
                let account = filteredAccounts[indexPath.row]
                controller.account = account
                controller.showAccountEnableButton = !Properties.hasValidSubscription && filteredAccounts.count > Properties.accountCap
                controller.canEnableAccount = filteredAccounts.filter({ $0.enabled }).count < Properties.accountCap
            }
        } else if segue.identifier == "ShowAddSubscription", let destination = segue.destination.contents as? SubscriptionViewController {
            destination.presentedModally = true
        }
    }

    func updateAccount(notification: Notification) {
        guard let account = notification.userInfo?["account"] as? UserAccount else {
            return
        }
        if let filteredIndex = filteredAccounts.firstIndex(where: { account.id == $0.id }) {
            filteredAccounts[filteredIndex] = account
            let indexPath = IndexPath(row: filteredIndex, section: 0)
            tableView.reloadRows(at: [indexPath], with: .automatic)
        }
        if !Properties.hasValidSubscription && Properties.accountOverflow {
            addAccountButton?.isEnabled = filteredAccounts.filter({ $0.enabled }).count < Properties.accountCap
        }
    }


    func addAccount(account: UserAccount) {
        unfilteredAccounts.append(account)
        filteredAccounts = unfilteredAccounts.sorted(by: { $0.site.name.lowercased() < $1.site.name.lowercased() })
        if let filteredIndex = filteredAccounts.firstIndex(where: { account.id == $0.id }) {
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
            if let index = filteredAccounts.firstIndex(where: { account.id == $0.id }) {
                let indexPath = IndexPath(row: index, section: 0)
                deleteAccount(account: account, filteredIndexPath: indexPath)
            }
        }
    }

    // MARK: - Private

    private func deleteAccount(account: Account, filteredIndexPath: IndexPath) {
        firstly {
            account.delete()
        }.done(on: DispatchQueue.main) {
            self.filteredAccounts.remove(at: filteredIndexPath.row)
            self.unfilteredAccounts.removeAll(where: { $0.id == account.id })
            self.tableView.deleteRows(at: [filteredIndexPath], with: .fade)
            self.updateUi()
        }.catch(on: DispatchQueue.main) { error in
            self.showAlert(message: error.localizedDescription, title: "errors.deleting_account".localized)
        }
    }

    private func addAddButton(enabled: Bool){
//        guard self.navigationItem.rightBarButtonItem == nil else {
//            return
//        }

        addAccountButton = KeynBarButton(frame: CGRect(x: 0, y: 0, width: 40, height: 40))
        addAccountButton!.setImage(UIImage(named:"add_button"), for: .normal)
        addAccountButton!.addTarget(self, action: enabled ? #selector(showAddAccount) : #selector(showAddSubscription), for: .touchUpInside)
        self.navigationItem.rightBarButtonItem = addAccountButton!.barButtonItem
    }
}
