/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import PromiseKit

enum Filters: Int {
    case all
    case team
    case personal

    func text() -> String {
        switch self {
        case .all: return "accounts.all".localized
        case .team: return "accounts.team".localized
        case .personal: return "accounts.personal".localized
        }
    }
}

class AccountsTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource, UIScrollViewDelegate {
    
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var tableView: UITableView!
    var unfilteredAccounts: [Account]!
    var filteredAccounts: [Account]!
    @IBOutlet weak var tableViewContainer: UIView!
    @IBOutlet weak var addAccountContainerView: UIView!
    @IBOutlet weak var tableViewFooter: UILabel!
    @IBOutlet weak var loadingSpinner: UIActivityIndicatorView!
    @IBOutlet weak var upgradeButton: KeynButton!
    @IBOutlet weak var upgradeButtonHeightConstraint: NSLayoutConstraint!
    @IBOutlet weak var bottomMarginConstraint: NSLayoutConstraint!
    @IBOutlet weak var sortLabel: UILabel!
    @IBOutlet weak var searchBar: UISearchBar!

    var sortingButton: AccountsPickerButton!
    var addAccountButton: KeynBarButton?
    var currentFilter = Filters.all
    var currentSortingValue = Properties.sortingPreference
    var searchQuery = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        if let accountDict = try? UserAccount.all(context: nil) {
            unfilteredAccounts = Array(accountDict.values).sorted(by: { $0.site.name.lowercased() < $1.site.name.lowercased() })
        } else {
            unfilteredAccounts = [UserAccount]()
        }

        prepareAccounts()
        updateUi()

        scrollView.delegate = self
        tableView.delegate = self
        tableView.dataSource = self

        self.extendedLayoutIncludesOpaqueBars = false
        self.definesPresentationContext = true
        NotificationCenter.default.addObserver(forName: .accountsLoaded, object: nil, queue: OperationQueue.main, using: loadAccounts)
        NotificationCenter.default.addObserver(forName: .sharedAccountsChanged, object: nil, queue: OperationQueue.main, using: loadAccounts)
        NotificationCenter.default.addObserver(forName: .accountUpdated, object: nil, queue: OperationQueue.main, using: updateAccount)
        NotificationCenter.default.addObserver(forName: .subscriptionUpdated, object: nil, queue: OperationQueue.main, using: updateSubscriptionStatus)

        setFooter()

        searchBar.placeholder = "accounts.search".localized
        searchBar.setScopeBarButtonTitleTextAttributes([
            NSAttributedString.Key.font : UIFont.primaryMediumNormal as Any,
            NSAttributedString.Key.foregroundColor : UIColor.primary,
        ], for: .normal)
        searchBar.scopeButtonTitles = [
            Filters.all.text(),
            Filters.team.text(),
            Filters.personal.text()
        ]
        searchBar.delegate = self
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
                self.prepareAccounts()
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
            addBarButtons(enabled: Properties.hasValidSubscription || accounts.count < Properties.accountCap)
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
            self.prepareAccounts()
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

    @IBAction func showSortValuesPicker(_ sender: Any) {
        sortingButton.becomeFirstResponder()
    }
    
    func prepareAccounts() {
        filteredAccounts = searchAccounts(accounts: unfilteredAccounts)
        filteredAccounts = filterAccounts(accounts: filteredAccounts)
        filteredAccounts = sortAccounts(accounts: filteredAccounts)
    }

    func searchAccounts(accounts: [Account]) -> [Account] {
        return searchQuery == "" ? unfilteredAccounts : unfilteredAccounts.filter({ (account) -> Bool in
            return account.site.name.lowercased().contains(searchQuery.lowercased())
        })
    }

    func filterAccounts(accounts: [Account]) -> [Account] {
        switch currentFilter {
        case .all:
            return accounts
        case .team:
            return accounts.filter { $0 is SharedAccount }
        case .personal:
            return accounts.filter { $0 is UserAccount }
        }
    }

    func sortAccounts(accounts: [Account]) -> [Account] {
        switch currentSortingValue {
        case .alphabetically: return sortAlphabetically(accounts: accounts)
        case .mostly: return sortMostlyUsed(accounts: accounts)
        case .recently: return sortRecentlyUsed(accounts: accounts)
        }
    }

    func sortAlphabetically(accounts: [Account]) -> [Account] {
        return accounts.sorted(by: { $0.site.name.lowercased() < $1.site.name.lowercased() })
    }

    func sortMostlyUsed(accounts: [Account]) -> [Account] {
        return accounts.sorted(by: { $0.timesUsed > $1.timesUsed })
    }

    func sortRecentlyUsed(accounts: [Account]) -> [Account] {
        return accounts.sorted(by: { current, next in
            if current.lastTimeUsed == nil {
                return false
            } else if next.lastTimeUsed == nil {
                return true
            } else if let currentLastTimeUsed = current.lastTimeUsed, let nextLastTimeUsed = next.lastTimeUsed {
                return currentLastTimeUsed > nextLastTimeUsed
            } else {
                return false
            }
        })
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

        // Update the account on the unfiltered array in case it is not visible at the moment.
        if let unfilteredIndex = unfilteredAccounts.firstIndex(where: { account.id == $0.id }) {
            unfilteredAccounts[unfilteredIndex] = account
        }
        // Will return the same UI
        // The updated account will be now included
        prepareAccounts()
        tableView.reloadData()
        // For this to work we should use diffing on the data source.
        // Because in cases where the order of the rows change, for example recent use, this will not be correct.
//        if let filteredIndex = filteredAccounts.firstIndex(where: { account.id == $0.id }) {
//            let indexPath = IndexPath(row: filteredIndex, section: 0)
//             tableView.reloadRows(at: [indexPath], with: .automatic)
//        }
        if !Properties.hasValidSubscription && Properties.accountOverflow {
            addAccountButton?.isEnabled = filteredAccounts.filter({ $0.enabled }).count < Properties.accountCap
        }
    }


    func addAccount(account: UserAccount) {
        unfilteredAccounts.append(account)
        prepareAccounts()
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
        } else if sender.identifier == "DeleteAccount", let sourceViewController = sender.source as? AccountViewController, let account = sourceViewController.account, let index = filteredAccounts.firstIndex(where: { account.id == $0.id }) {
            let indexPath = IndexPath(row: index, section: 0)
            deleteAccount(account: account, filteredIndexPath: indexPath)
        } else if sender.identifier == "DeleteUserAccount", let sourceViewController = sender.source as? TeamAccountViewController, let account = sourceViewController.account, let index = filteredAccounts.firstIndex(where: { sourceViewController.account.id == $0.id && $0 is UserAccount }) {
            let indexPath = IndexPath(row: index, section: 0)
            deleteAccountFromTable(indexPath: indexPath, id: account.id)
        }
    }

    // MARK: - Private

    private func deleteAccount(account: Account, filteredIndexPath: IndexPath) {
        firstly {
            account.delete()
        }.done(on: DispatchQueue.main) {
            self.deleteAccountFromTable(indexPath: filteredIndexPath, id: account.id)
        }.catch(on: DispatchQueue.main) { error in
            self.showAlert(message: error.localizedDescription, title: "errors.deleting_account".localized)
        }
    }

    private func deleteAccountFromTable(indexPath: IndexPath, id: String) {
        self.filteredAccounts.remove(at: indexPath.row)
        self.unfilteredAccounts.removeAll(where: { $0.id == id })
        self.tableView.deleteRows(at: [indexPath], with: .fade)
        self.updateUi()
    }

    private func addBarButtons(enabled: Bool){
        if addAccountButton == nil {
            addAccountButton = KeynBarButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
            addAccountButton!.setImage(UIImage(named:"add_button"), for: .normal)
        }
        addAccountButton!.addTarget(self, action: enabled ? #selector(showAddAccount) : #selector(showAddSubscription), for: .touchUpInside)
        self.navigationItem.rightBarButtonItem = addAccountButton!.barButtonItem

        if sortingButton == nil {
            sortingButton = AccountsPickerButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
            sortingButton!.setImage(UIImage(named:"filter_button"), for: .normal)
            sortingButton.picker.delegate = self
            sortingButton.picker.dataSource = self
            sortingButton.picker.selectRow(currentSortingValue.rawValue, inComponent: 0, animated: false)
            sortingButton!.addTarget(self, action: #selector(showAddAccount), for: .touchUpInside)
            self.navigationItem.leftBarButtonItem = sortingButton!.barButtonItem
        }
    }
}

extension AccountsTableViewController: UISearchBarDelegate {
    func searchBar(_ searchBar: UISearchBar, selectedScopeButtonIndexDidChange selectedScope: Int) {
        guard let filter = Filters(rawValue: selectedScope) else {
            return
        }
        currentFilter = filter
        prepareAccounts()
        tableView.reloadData()
    }

    func searchBarTextDidBeginEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(true, animated: true)
        if #available(iOS 13.0, *) {
            searchBar.setShowsScope(true, animated: true)
        } else {
            searchBar.showsScopeBar = true
        }
    }

    func searchBarTextDidEndEditing(_ searchBar: UISearchBar) {
        searchBar.setShowsCancelButton(false, animated: true)
        if #available(iOS 13.0, *) {
            searchBar.setShowsScope(false, animated: true)
        } else {
            searchBar.showsScopeBar = false
        }
    }

    func searchBarCancelButtonClicked(_ searchBar: UISearchBar) {
        searchBar.endEditing(true)
    }

    func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        if let searchText = searchBar.text {
            searchQuery = searchText
        } else {
            searchQuery = ""
        }
        prepareAccounts()
        tableView.reloadData()
    }
}

extension AccountsTableViewController: UIPickerViewDelegate, UIPickerViewDataSource {
    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return SortingValue.all.count
    }

    func pickerView(_ pickerView: UIPickerView, titleForRow row: Int, forComponent component: Int) -> String? {
        return SortingValue(rawValue: row)!.text
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        currentSortingValue = SortingValue(rawValue: row)!
        Properties.sortingPreference = currentSortingValue
        prepareAccounts()
        tableView.reloadData()
    }
}
