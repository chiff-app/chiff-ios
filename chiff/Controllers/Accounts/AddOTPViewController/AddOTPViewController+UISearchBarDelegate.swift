//
//  AddOTPViewController+UISearchBarDelegate.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore

extension AddOTPViewController: UISearchBarDelegate {

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
        filteredAccounts = sortAccounts(accounts: filteredAccounts)
    }

    func searchAccounts(accounts: [UserAccount]) -> [UserAccount] {
        return searchQuery.isEmpty ? unfilteredAccounts : unfilteredAccounts.filter({ (account) -> Bool in
            return account.site.name.lowercased().contains(searchQuery.lowercased())
        })
    }

    func sortAccounts(accounts: [UserAccount]) -> [UserAccount] {
        switch currentSortingValue {
        case .alphabetically: return sortAlphabetically(accounts: accounts)
        case .mostly: return sortMostlyUsed(accounts: accounts)
        case .recently: return sortRecentlyUsed(accounts: accounts)
        }
    }

    func sortAlphabetically(accounts: [UserAccount]) -> [UserAccount] {
        return accounts.sorted(by: { $0.site.name.lowercased() < $1.site.name.lowercased() })
    }

    func sortMostlyUsed(accounts: [UserAccount]) -> [UserAccount] {
        return accounts.sorted(by: { $0.timesUsed > $1.timesUsed })
    }

    func sortRecentlyUsed(accounts: [UserAccount]) -> [UserAccount] {
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
