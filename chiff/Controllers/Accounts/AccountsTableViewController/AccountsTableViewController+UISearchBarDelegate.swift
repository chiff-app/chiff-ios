//
//  AccountsTableViewController+UISearchBarDelegate.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore

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

    func prepareAccounts() {
        filteredAccounts = searchAccounts(accounts: unfilteredAccounts)
        filteredAccounts = filterAccounts(accounts: filteredAccounts)
        filteredAccounts = sortAccounts(accounts: filteredAccounts)
    }

    func searchAccounts(accounts: [Identity]) -> [Identity] {
        return searchQuery.isEmpty ? unfilteredAccounts : unfilteredAccounts.filter({ (account) -> Bool in
            return account.name.lowercased().contains(searchQuery.lowercased())
        })
    }

    func filterAccounts(accounts: [Identity]) -> [Identity] {
        switch currentFilter {
        case .all:
            return accounts
        case .team:
            return accounts.filter { $0 is SharedAccount }
        case .personal:
            return accounts.filter { $0 is UserAccount }
        }
    }

    func sortAccounts(accounts: [Identity]) -> [Identity] {
        switch currentSortingValue {
        case .alphabetically: return sortAlphabetically(accounts: accounts)
        case .mostly: return sortMostlyUsed(accounts: accounts)
        case .recently: return sortRecentlyUsed(accounts: accounts)
        }
    }

    func sortAlphabetically(accounts: [Identity]) -> [Identity] {
        return accounts.sorted(by: { $0.name.lowercased() < $1.name.lowercased() })
    }

    func sortMostlyUsed(accounts: [Identity]) -> [Identity] {
        return accounts.sorted(by: { $0.timesUsed > $1.timesUsed })
    }

    func sortRecentlyUsed(accounts: [Identity]) -> [Identity] {
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
}
