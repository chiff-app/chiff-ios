//
//  AccountsTableViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import PromiseKit
import ChiffCore
import AuthenticationServices

class AccountsTableViewController: UIViewController, UITableViewDelegate, UIScrollViewDelegate {

    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var tableView: UITableView!
    var unfilteredAccounts: [Identity]!
    var filteredAccounts: [Identity]!
    @IBOutlet weak var tableViewContainer: UIView!
    @IBOutlet weak var addAccountContainerView: UIView!
    @IBOutlet weak var tableViewFooter: UILabel!
    @IBOutlet weak var loadingSpinner: UIActivityIndicatorView!
    @IBOutlet weak var sortLabel: UILabel!
    @IBOutlet weak var searchBar: UISearchBar!
    @IBOutlet weak var buttonHeight: NSLayoutConstraint!
    @IBOutlet weak var topButtonConstraint: NSLayoutConstraint!
    @IBOutlet weak var enableAutofillButton: KeynButton!

    var sortingButton: AccountsPickerButton!
    var addAccountButton: KeynBarButton?
    var currentFilter = Filters.all
    var currentSortingValue = Properties.sortingPreference
    var searchQuery = ""

    override func viewDidLoad() {
        super.viewDidLoad()

        if let accountDict = try? UserAccount.allCombined(context: nil) {
            unfilteredAccounts = Array(accountDict.values).sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
        } else {
            unfilteredAccounts = [Identity]()
        }
        if let sshIdentities = try? SSHIdentity.all(context: nil) {
            unfilteredAccounts.append(contentsOf: Array(sshIdentities.values).sorted(by: { $0.name.lowercased() < $1.name.lowercased() }))
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
        if let index = unfilteredAccounts.firstIndex(where: { $0.id == account.id && $0 is SharedAccount }) {
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
    }

    func deleteAccount(account: Identity, filteredIndexPath: IndexPath) {
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
        switch segue.identifier {
        case "ShowAccount":
            if let controller = (segue.destination.contents as? AccountViewController),
               let account = sender as? Account {
                controller.account = account
            }
        case "ShowDeveloperIdentity":
            if let controller = (segue.destination.contents as? SSHIdentityViewController),
               let identity = sender as? SSHIdentity {
                controller.identity = identity
            }
        default: return
        }
    }

    // MARK: - Actions

    @IBAction func showSortValuesPicker(_ sender: Any) {
        sortingButton.becomeFirstResponder()
    }

    @IBAction func unwindToAccountOverview(sender: UIStoryboardSegue) {
        if let sourceViewController = sender.source as? AddAccountViewController, let account = sourceViewController.account {
            addAccount(account: account)
        } else {
            switch sender.identifier {
            case "DeleteAccount":
                guard let sourceViewController = sender.source as? AccountViewController,
                   let account = sourceViewController.account,
                   let index = filteredAccounts.firstIndex(where: { account.id == $0.id }) else {
                    return
                }
                let indexPath = IndexPath(row: index, section: 0)
                deleteAccount(account: account, filteredIndexPath: indexPath)
            case "DeleteSSHIdentity":
                guard let sourceViewController = sender.source as? SSHIdentityViewController,
                   let identity = sourceViewController.identity,
                   let index = filteredAccounts.firstIndex(where: { identity.id == $0.id }) else {
                    return
                }
                let indexPath = IndexPath(row: index, section: 0)
                deleteAccount(account: identity, filteredIndexPath: indexPath)
            case "UpdateSSHIdentity":
                guard let sourceViewController = sender.source as? SSHIdentityViewController,
                   var identity = sourceViewController.identity,
                   let index = unfilteredAccounts.firstIndex(where: { identity.id == $0.id }),
                   let name = sourceViewController.nameTextField.text,
                   name != identity.name else {
                    return
                }
                do {
                    try identity.updateName(to: name)
                    unfilteredAccounts[index] = identity
                    prepareAccounts()
                    tableView.reloadData()
                } catch {
                    Logger.shared.error("Error updating SSH identity", error: error)
                }
            case "DeleteUserAccount":
                guard let sourceViewController = sender.source as? TeamAccountViewController,
                      let account = sourceViewController.account,
                      let index = filteredAccounts.firstIndex(where: { sourceViewController.account.id == $0.id && $0 is UserAccount }) else {
                    return
                }
                let indexPath = IndexPath(row: index, section: 0)
                deleteAccountFromTable(indexPath: indexPath, id: account.id)
            case "DenyAutofill":
                Properties.deniedAutofill = true
                updateUi()
            default:
                guard let sourceViewController = sender.source as? AddAccountViewController,
                      let account = sourceViewController.account else {
                    return
                }
                addAccount(account: account)
            }
        }
    }

    // MARK: - Private functions

    @objc private func showAddAccount() {
        performSegue(withIdentifier: "ShowAddAccount", sender: self)
    }

    @objc private func loadAccounts(notification: Notification?) {
        DispatchQueue.main.async {
            if let accounts = try? notification?.userInfo as? [String: Account] ?? UserAccount.allCombined(context: nil) {
                self.unfilteredAccounts = accounts.values.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
                if let sshIdentities = try? SSHIdentity.all(context: nil) {
                    self.unfilteredAccounts.append(contentsOf: sshIdentities.values.sorted(by: { $0.name.lowercased() < $1.name.lowercased() }))
                }
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
        if let accounts = unfilteredAccounts, !accounts.isEmpty {
            tableViewContainer.isHidden = false
            addAccountContainerView.isHidden = true
            addBarButtons()
            func hideAutofillButton() {
                if !self.enableAutofillButton.isHidden {
                    self.enableAutofillButton.isHidden = true
                    self.buttonHeight.constant = 0
                    self.topButtonConstraint.constant = 0
                    self.view.layoutIfNeeded()
                }
            }
            guard !Properties.deniedAutofill else {
                hideAutofillButton()
                return
            }
            ASCredentialIdentityStore.shared.getState { (state) in
                DispatchQueue.main.async {
                    if !state.isEnabled {
                        self.enableAutofillButton.isHidden = false
                        self.buttonHeight.constant = 44.0
                        self.topButtonConstraint.constant = 10.0
                        self.view.layoutIfNeeded()
                    } else {
                        hideAutofillButton()
                    }
                }
            }
        } else {
            navigationItem.rightBarButtonItem = nil
            navigationItem.leftBarButtonItem = nil
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
