//
//  UnlimitedViewController.swift
//  keyn
//
//  Created by Bas Doorn on 08/07/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit
import StoreKit

class SubscriptionViewController: UIViewController, UICollectionViewDelegate, UICollectionViewDataSource, UITextViewDelegate {

    @IBOutlet weak var collectionView: UICollectionView!
    @IBOutlet weak var activityView: UIActivityIndicatorView!
    @IBOutlet weak var upgradeButton: KeynButton!
    @IBOutlet weak var disclaimerTextView: UITextView!

    var presentedModally = false

    override func viewDidLoad() {
        super.viewDidLoad()
        StoreObserver.shared.delegate = self
        StoreManager.shared.delegate = self
        collectionView.delegate = self
        collectionView.dataSource = self
        fetchProductInformation()
        setDisclaimerText()
        if presentedModally {
            navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.cancel, target: self, action: #selector(cancel))
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
        if Properties.hasValidSubscription, let productId = Properties.subscriptionProduct, productId == product.productIdentifier {
            cell.type = .active
            if cell.isSelected {
                upgradeButton.isEnabled = false
            }
        } else if indexPath.row == 0 {
            cell.type = .none
        } else {
            cell.type = .discount
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

    // MARK: - Disclaimer

    private func setDisclaimerText() {
        disclaimerTextView.delegate = self
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        let disclaimer = "settings.disclaimer".localized
        let termsOfService = "settings.terms_of_service".localized
        let privacyPolicy = "settings.privacy_policy".localized
        let and = "settings.and".localized
        let attributedString = NSMutableAttributedString(string: "\(disclaimer) \(termsOfService) \(and) \(privacyPolicy).", attributes: [
            .paragraphStyle: paragraph,
            .foregroundColor: UIColor.primaryHalfOpacity,
            .font: UIFont.primaryMediumSmall!
            ])

        let termsOfServiceUrlPath = Bundle.main.path(forResource: "privacy_policy", ofType: "html")
        let privacyPolicyUrlPath = Bundle.main.path(forResource: "privacy_policy", ofType: "html")

        let termsOfServiceUrl = URL(fileURLWithPath: termsOfServiceUrlPath!)
        let privacyPolicyUrl = URL(fileURLWithPath: privacyPolicyUrlPath!)

        attributedString.setAttributes([
            .link: termsOfServiceUrl,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: UIFont.primaryMediumSmall!
            ], range: NSMakeRange(disclaimer.count + 1, termsOfService.count))
        attributedString.setAttributes([
            .link: privacyPolicyUrl,
            .underlineStyle: NSUnderlineStyle.single.rawValue,
            .font: UIFont.primaryMediumSmall!
            ], range: NSMakeRange(disclaimer.count + termsOfService.count + and.count + 3, privacyPolicy.count))
        disclaimerTextView.attributedText = attributedString
        disclaimerTextView.linkTextAttributes = [
            .foregroundColor: UIColor.primary
        ]
    }

    // MARK: - UITextViewDelegate

    func textView(_ textView: UITextView, shouldInteractWith URL: URL, in characterRange: NSRange) -> Bool {
        self.performSegue(withIdentifier: "ShowUrlViewController", sender: URL)
        return false
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "ShowUrlViewController", let destination = segue.destination.contents as? WebViewController, let url = sender as? URL {
            destination.url = url
            destination.presentedModally = true
        }
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
        let cell = collectionView.cellForItem(at: indexPath) as! ProductCollectionViewCell
        cell.showSelected()
        upgradeButton.isEnabled = cell.type != .active
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
        reload()
        showMessage(message: "settings.restore_successful".localized)
    }

    fileprivate func finishPurchase() {
        if presentedModally {
            cancel()
        } else {
            reload()
        }
    }

    fileprivate func showMessage(message: String) {
        let alert = UIAlertController(title: "settings.success".localized, message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true)
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
    func storeObserverCrossgrade() {
        upgradeButton.hideLoading()
        showMessage(message: "settings.crossgrade_successful".localized)
    }

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

    func storeObserverRestoreNoProducts() {
        upgradeButton.hideLoading()
        showError(message: "settings.restore_failed".localized)
    }

    func storeObserverPurchaseDidFail() {
        upgradeButton.hideLoading()
        showError(message: "settings.purchase_failed".localized)
    }

    func storeObserverRestoreDidFail() {
        upgradeButton.hideLoading()
        showError(message: "settings.restore_failed".localized)
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
    
