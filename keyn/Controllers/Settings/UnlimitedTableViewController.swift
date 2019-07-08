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

    private var products = [SKProduct]()

    override func viewDidLoad() {
        super.viewDidLoad()
        StoreObserver.shared.delegate = self    // TODO: Or should Root / App be observer? User could navigate away?
        StoreManager.shared.delegate = self
        fetchProductInformation()
    }

    // MARK: - Table view data source

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return "TODO"
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "available", for: indexPath)
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let product = products[indexPath.row]
        cell.textLabel!.text = product.localizedTitle
        if let price = product.regularPrice {
            cell.detailTextLabel?.text = "\(price)"
        }
    }

    /// Starts a purchase when the user taps an available product row.
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        StoreObserver.shared.buy(products[indexPath.row])
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
            StoreManager.shared.startProductRequest()
        } else {
            // Warn the user that they are not allowed to make purchases.
            showError(message: "Not authorized")
        }
    }

    fileprivate func reload(with data: [SKProduct]) {
        self.products = data
        tableView.reloadData()
    }


    // MARK: - Handle Restored Transactions

    /// Handles successful restored transactions.
    fileprivate func handleRestoredSucceededTransaction() {
        print("TODO")
    }

}

extension UnlimitedViewController: StoreManagerDelegate {

    func storeManagerDidReceiveResponse(_ response: [SKProduct]) {
        reload(with: response)
    }

    func storeManagerDidReceiveMessage(_ message: String) {
        showError(message: message)
    }

}

/// Extends ParentViewController to conform to StoreObserverDelegate.
extension UnlimitedViewController: StoreObserverDelegate {
    func storeObserverDidReceiveMessage(_ message: String) {
        showError(message: message)
    }

    func storeObserverRestoreDidSucceed() {
        handleRestoredSucceededTransaction()
    }
}
