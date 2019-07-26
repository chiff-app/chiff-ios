//
//  UnlimitedViewController.swift
//  keyn
//
//  Created by Bas Doorn on 08/07/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit
import StoreKit

class SubscriptionViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var activityView: UIActivityIndicatorView!
    @IBOutlet weak var upgradeButton: KeynButton!

    var presentedModally = false

    override func viewDidLoad() {
        super.viewDidLoad()
        StoreObserver.shared.delegate = self
        StoreManager.shared.delegate = self
        collectionView.delegate = self
        collectionView.dataSource = self
        fetchProductInformation()
        if presentedModally {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.cancel, target: self, action: #selector(cancel))
        }
        if !StoreManager.shared.availableProducts.isEmpty {
            activityView.stopAnimating()
            select(index: nil)
        }
    }

    // MARK: - Table view data source

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return StoreManager.shared.availableProducts.count
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        return collectionView.dequeueReusableCell(withReuseIdentifier: "ProductCell", for: indexPath)
    }

    // MARK: - UITableViewDelegate

    func collectionView(_ collectionView: UICollectionView, willDisplay cell: UICollectionViewCell, forItemAt indexPath: IndexPath) {
        let product = StoreManager.shared.availableProducts[indexPath.row]
        let cell = cell as! ProductCollectionViewCell
        cell.isFirst = indexPath.row == 0
        cell.showSelected()
        cell.title.text = product.localizedTitle
        if let price = product.regularPrice {
            cell.price.text = "\(price)"
        }
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        updateCellSelectionUI(indexPath: indexPath)
    }

    func collectionView(_ collectionView: UICollectionView, didDeselectItemAt indexPath: IndexPath) {
        updateCellSelectionUI(indexPath: indexPath)
    }

    // MARK: - Navigation

    @objc func cancel() {
        (presentingViewController as? RequestViewController)?.dismiss() ?? dismiss(animated: true, completion: nil)
    }

    // MARK: - Fetch Product Information

    /// Retrieves product information from the App Store.
    private func fetchProductInformation() {
        if StoreObserver.shared.isAuthorizedForPayments {
            StoreManager.shared.startProductRequest()
        } else {
            // Warn the user that they are not allowed to make purchases.
            showError(message: "Not authorized")
        }
    }

    private func select(index: Int?) {
        let indexPath = IndexPath(row: index ?? StoreManager.shared.availableProducts.count - 1, section: 0)
        collectionView.selectItem(at: indexPath, animated: false, scrollPosition: [])
    }

    private func updateCellSelectionUI(indexPath: IndexPath) {
        (collectionView.cellForItem(at: indexPath) as! ProductCollectionViewCell).showSelected()
    }

    fileprivate func reload() {
        if let selected = collectionView.indexPathsForSelectedItems?.first {
            collectionView.reloadData()
            select(index: selected.row)
        } else {
            collectionView.reloadData()
            select(index: nil)
        }
    }

    // MARK: - Handle Restored Transactions

    /// Handles successful restored transactions.
    fileprivate func handleRestoredSucceededTransaction() {
        print("Transactions successfully restored")
    }

    fileprivate func finishPurchase() {
        // If this purchase is done in the requestView flow, dismiss
        guard presentedModally else { return }
        cancel()
    }

    // MARK: - Actions

    @IBAction func restore(_ sender: UIButton) {
        upgradeButton.showLoading()
        StoreObserver.shared.restore()
    }

    @IBAction func upgrade(_ sender: KeynButton) {
        if let selected = collectionView.indexPathsForSelectedItems?.first {
            sender.showLoading()
            StoreObserver.shared.buy(StoreManager.shared.availableProducts[selected.row])
        }
    }


}

extension SubscriptionViewController: StoreManagerDelegate {

    func storeManagerDidReceiveResponse() {
        activityView.stopAnimating()
        reload()
    }

    func storeManagerDidReceiveMessage(_ message: String) {
        activityView.stopAnimating()
        showError(message: message)
    }

}

/// Extends ParentViewController to conform to StoreObserverDelegate.
extension SubscriptionViewController: StoreObserverDelegate {
    func storeObserverDidReceiveMessage(_ message: String) {
        upgradeButton.hideLoading()
        showError(message: message)
    }

    func storeObserverPurchaseDidSucceed() {
        upgradeButton.hideLoading()
        finishPurchase()
    }

    func storeObserverRestoreDidSucceed() {
        upgradeButton.hideLoading()
        handleRestoredSucceededTransaction()
    }

    func storeObserverPurchaseCancelled() {
        upgradeButton.hideLoading()
    }
}

// Conform UICollectionViewDelegateFlowLayout first
extension SubscriptionViewController: UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: self.collectionView.bounds.width / 2, height: self.collectionView.bounds.height)
    }

}
    
