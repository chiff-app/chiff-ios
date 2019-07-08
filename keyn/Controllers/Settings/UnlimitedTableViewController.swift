//
//  UnlimitedViewController.swift
//  keyn
//
//  Created by Bas Doorn on 08/07/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit
import StoreKit

class UnlimitedViewController: UITableViewController {

    fileprivate struct CellIdentifiers {
        static let availableProduct = "available"
        static let invalidIdentifier = "invalid"
    }

    private var data = [Section]()

    override func viewDidLoad() {
        super.viewDidLoad()

        StoreManager.shared.delegate = self

        fetchProductInformation()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return data.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return data[section].elements.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return data[section].type.description
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let section = data[indexPath.section]

        if section.type == .availableProducts {
            return tableView.dequeueReusableCell(withIdentifier: CellIdentifiers.availableProduct, for: indexPath)
        } else {
            return tableView.dequeueReusableCell(withIdentifier: CellIdentifiers.invalidIdentifier, for: indexPath)
        }
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let section = data[indexPath.section]

        // If there are available products, show them.
        if section.type == .availableProducts, let content = section.elements as? [SKProduct] {
            let product = content[indexPath.row]

            // Show the localized title of the product.
            cell.textLabel!.text = product.localizedTitle

            // Show the product's price in the locale and currency returned by the App Store.
            cell.detailTextLabel?.text = "\(product.price)"
        } else if section.type == .invalidProductIdentifiers, let content = section.elements as? [String] {
            // if there are invalid product identifiers, show them.
            cell.textLabel!.text = content[indexPath.row]
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        // Get the new view controller using segue.destination.
        // Pass the selected object to the new view controller.
    }
    */


    // MARK: - Fetch Product Information

    /// Retrieves product information from the App Store.
    private func fetchProductInformation() {
        // First, let's check whether the user is allowed to make purchases. Proceed if they are allowed. Display an alert, otherwise.
        if StoreObserver.shared.isAuthorizedForPayments {
            let identifiers = ["io.keyn.keyn", "io.keyn.keyn.yearly"]
            StoreManager.shared.startProductRequest(with: identifiers)
        } else {
            // Warn the user that they are not allowed to make purchases.
            showError(message: "Not authorized")
        }
    }

    fileprivate func reload(with data: [Section]) {
        self.data = data
        tableView.reloadData()
    }


}

extension UnlimitedViewController: StoreManagerDelegate {

    func storeManagerDidReceiveResponse(_ response: [Section]) {
        reload(with: response)
    }

    func storeManagerDidReceiveMessage(_ message: String) {
        showError(message: message)
    }

}
