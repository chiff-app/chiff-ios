//
//  AccountsTableViewController+UIPickerView.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

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
