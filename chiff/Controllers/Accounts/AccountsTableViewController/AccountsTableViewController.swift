//
//  AccountsTableViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

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

class AccountsTableViewController: UIViewController, UITableViewDelegate, UIScrollViewDelegate {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var tableView: UITableView!
    var unfilteredAccounts: [Account]!
    var filteredAccounts: [Account]!
    @IBOutlet weak var tableViewContainer: UIView!
    @IBOutlet weak var addAccountContainerView: UIView!
    @IBOutlet weak var tableViewFooter: UILabel!
    @IBOutlet weak var loadingSpinner: UIActivityIndicatorView!
    @IBOutlet weak var sortLabel: UILabel!
    @IBOutlet weak var searchBar: UISearchBar!

    var sortingButton: AccountsPickerButton!
    var addAccountButton: KeynBarButton?
    var currentFilter = Filters.all
    var currentSortingValue = Properties.sortingPreference
    var searchQuery = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        if let accountDict = try? UserAccount.allCombined(context: nil) {
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

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(loadAccounts(notification:)), name: .accountsLoaded, object: nil)
        nc.addObserver(self, selector: #selector(loadAccounts(notification:)), name: .sharedAccountsChanged, object: nil)
        nc.addObserver(self, selector: #selector(updateAccount(notification:)), name: .accountUpdated, object: nil)

        tableViewFooter.text = "accounts.footer_unlimited".localized

        searchBar.placeholder = "accounts.search".localized
        searchBar.setScopeBarButtonTitleTextAttributes([
            NSAttributedString.Key.font: UIFont.primaryMediumNormal as Any,
            NSAttributedString.Key.foregroundColor: UIColor.primary
        ], for: .normal)
        searchBar.scopeButtonTitles = [
            Filters.all.text(),
            Filters.team.text(),
            Filters.personal.text()
        ]
        searchBar.delegate = self
    }

    func addAccount(account: UserAccount) {
        if let index = unfilteredAccounts.firstIndex(where: { ($0 as? SharedAccount)?.id == account.id }) {
            var account = account
            account.shadowing = true
            unfilteredAccounts[index] = account
            prepareAccounts()
            tableView.reloadData()
        } else {
            unfilteredAccounts.append(account)
            prepareAccounts()
            if let filteredIndex = filteredAccounts.firstIndex(where: { account.id == $0.id }) {
                let newIndexPath = IndexPath(row: filteredIndex, section: 0)
                tableView.insertRows(at: [newIndexPath], with: .automatic)
                self.updateUi()
            }
        }
//        updateSearchResults(for: searchController)
    }

    func deleteAccount(account: Account, filteredIndexPath: IndexPath) {
        firstly {
            account.delete()
        }.done(on: DispatchQueue.main) {
            self.deleteAccountFromTable(indexPath: filteredIndexPath, id: account.id)
            if (account as? UserAccount)?.shadowing ?? false {
                self.loadAccounts(notification: nil)
            }
        }.catch(on: DispatchQueue.main) { error in
            self.showAlert(message: error.localizedDescription, title: "errors.deleting_account".localized)
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
            }
        }
    }

    // MARK: - Actions

    @IBAction func showSortValuesPicker(_ sender: Any) {
        sortingButton.becomeFirstResponder()
    }

    @IBAction func unwindToAccountOverview(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? AddAccountViewController, let account = sourceViewController.account {
            addAccount(account: account)
        } else if sender.identifier == "DeleteAccount",
                  let sourceViewController = sender.source as? AccountViewController,
                  let account = sourceViewController.account,
                  let index = filteredAccounts.firstIndex(where: { account.id == $0.id }) {
            let indexPath = IndexPath(row: index, section: 0)
            deleteAccount(account: account, filteredIndexPath: indexPath)
        } else if sender.identifier == "DeleteUserAccount", let sourceViewController = sender.source as? TeamAccountViewController,
                  let account = sourceViewController.account,
                  let index = filteredAccounts.firstIndex(where: { sourceViewController.account.id == $0.id && $0 is UserAccount }) {
            let indexPath = IndexPath(row: index, section: 0)
            deleteAccountFromTable(indexPath: indexPath, id: account.id)
        }
    }

    // MARK: - Private

    @objc private func showAddAccount() {
        performSegue(withIdentifier: "ShowAddAccount", sender: self)
    }

    @objc private func loadAccounts(notification: Notification?) {
        DispatchQueue.main.async {
            if let accounts = try? notification?.userInfo as? [String: Account] ?? UserAccount.allCombined(context: nil) {
                self.unfilteredAccounts = accounts.values.sorted(by: { $0.site.name.lowercased() < $1.site.name.lowercased() })
                self.prepareAccounts()
                self.tableView.reloadData()
                self.updateUi()
            }
        }
    }

    @objc private func updateAccount(notification: Notification) {
        guard let account = notification.userInfo?["account"] as? Account else {
            return
        }

        // Update the account on the unfiltered array in case it is not visible at the moment.
        if let unfilteredIndex = unfilteredAccounts.firstIndex(where: { account.id == $0.id }) {
            unfilteredAccounts[unfilteredIndex] = account
        }
        prepareAccounts()
        tableView.reloadData()
    }

    private func updateUi() {
        loadingSpinner.stopAnimating()
        if let accounts = filteredAccounts, !accounts.isEmpty {
            tableViewContainer.isHidden = false
            addAccountContainerView.isHidden = true
            addBarButtons()
        } else {
            navigationItem.rightBarButtonItem = nil
            tableViewContainer.isHidden = true
            addAccountContainerView.isHidden = false
        }
    }

    private func deleteAccountFromTable(indexPath: IndexPath, id: String) {
        self.filteredAccounts.remove(at: indexPath.row)
        self.unfilteredAccounts.removeAll(where: { $0.id == id })
        self.tableView.deleteRows(at: [indexPath], with: .fade)
        self.updateUi()
    }

    private func addBarButtons() {
        if addAccountButton == nil {
            addAccountButton = KeynBarButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
            addAccountButton!.setImage(UIImage(named: "add_button"), for: .normal)
        }
        addAccountButton!.addTarget(self, action: #selector(showAddAccount), for: .touchUpInside)
        self.navigationItem.rightBarButtonItem = addAccountButton!.barButtonItem

        if sortingButton == nil {
            sortingButton = AccountsPickerButton(frame: CGRect(x: 0, y: 0, width: 30, height: 30))
            sortingButton!.setImage(UIImage(named: "filter_button"), for: .normal)
            sortingButton.picker.delegate = self
            sortingButton.picker.dataSource = self
            sortingButton.picker.selectRow(currentSortingValue.rawValue, inComponent: 0, animated: false)
            sortingButton!.addTarget(self, action: #selector(showAddAccount), for: .touchUpInside)
            self.navigationItem.leftBarButtonItem = sortingButton!.barButtonItem
        }
    }
}
