/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import StoreKit

// MARK: - StoreObserverDelegate

protocol StoreObserverDelegate: AnyObject {
    /// Tells the delegate that the restore operation was successful.
    func storeObserverRestoreDidSucceed()

    /// Tells the delegate that the purchase operation was successful.
    func storeObserverPurchaseDidSucceed()

    func storeObserverPurchaseCancelled()

    func storeObserverCrossgrade()

    /// Provides the delegate with messages.
    func storeObserverDidReceiveMessage(_ message: String)
}

enum ValidationResult: String {
    case success = "success"
    case failed = "failed"
    case error = "error"
}

class StoreObserver: NSObject {

    static let shared = StoreObserver()

    /// Keeps track of all purchases.
    var purchased = [SKPaymentTransaction]()

    var isAuthorizedForPayments: Bool {
        return SKPaymentQueue.canMakePayments()
    }

    weak var delegate: StoreObserverDelegate?

    private override init() {}

    func enable() {
        SKPaymentQueue.default().add(self)
    }

    func disable() {
        SKPaymentQueue.default().remove(self)
    }

    func buy(_ product: SKProduct) {
        let payment = SKMutablePayment(product: product)
        SKPaymentQueue.default().add(payment)
    }

    func restore() {
        let request = SKReceiptRefreshRequest(receiptProperties: nil)
        request.delegate = self
        request.start()
    }

    /// This retrieves current subscription status for this seed from the Keyn server
    func updateSubscriptions(completionHandler: @escaping (_ error: Error?) -> Void) {
        do {
            API.shared.signedRequest(endpoint: .subscription, method: .get, pubKey: try BackupManager.shared.publicKey(), privKey: try BackupManager.shared.privateKey()) { (result, error) in
                if let error = error {
                    completionHandler(error)
                } else if let subscriptions = result as? [String: TimeInterval], !subscriptions.isEmpty, let longest = subscriptions.max(by: { $0.value > $1.value }) {
                    if subscriptions.count > 1 {
                        Logger.shared.warning("Multiple active subscriptions", userInfo: subscriptions)
                    }
                    Properties.subscriptionExiryDate = longest.value
                    Properties.subscriptionProduct = longest.key
                    completionHandler(nil)

                } else {
                    Properties.subscriptionExiryDate = 0
                    Properties.subscriptionProduct = nil
                    completionHandler(nil)
                }
            }
        } catch {
            completionHandler(error)
        }
    }

    fileprivate func handleRefreshedReceipt() {
        validateReceipt { (result, expires, product, error) in
            DispatchQueue.main.async {
                switch result {
                case .error:
                    self.delegate?.storeObserverDidReceiveMessage(error?.localizedDescription ?? "")
                case .success:
                    Properties.subscriptionExiryDate = expires!
                    Properties.subscriptionProduct = product
                    self.delegate?.storeObserverRestoreDidSucceed()
                case .failed:
                    print("TODO")
                }
            }

        }
    }

    // MARK: - Handle Payment Transactions

    /// Handles successful purchase transactions.
    fileprivate func handlePurchased(_ transaction: SKPaymentTransaction) {
        purchased.append(transaction)
        print("\("storekit.deliverContent".localized) \(transaction.payment.productIdentifier).")

        validateReceipt { (result, expires, product, error) in
            DispatchQueue.main.async {
                switch result {
                case .error:
                    self.delegate?.storeObserverDidReceiveMessage(error?.localizedDescription ?? "")
                case .success:
                    Properties.subscriptionExiryDate = expires!
                    Properties.subscriptionProduct = product
                    self.delegate?.storeObserverPurchaseDidSucceed()
                case .failed:
                    print("TODO")
                }
            }

            SKPaymentQueue.default().finishTransaction(transaction)
        }
    }

    /// Handles failed purchase transactions.
    fileprivate func handleFailed(_ transaction: SKPaymentTransaction) {
        var message = "\("storekit.purchaseOf".localized) \(transaction.payment.productIdentifier) \("storekit.failed".localized)"

        if let error = transaction.error {
            message += "\n\("storekit.error".localized) \(error.localizedDescription)"
        }

        // Do not send any notifications when the user cancels the purchase.
        let code = (transaction.error as? SKError)?.code
        DispatchQueue.main.async {
            if code == .paymentCancelled {
                self.delegate?.storeObserverPurchaseCancelled()
            } else if code == .unknown { // This probably indicated that a crossgrade SUCCEEDED
                self.delegate?.storeObserverCrossgrade()
            } else {
                self.delegate?.storeObserverDidReceiveMessage(message)
            }
        }

        // Finish the failed transaction.
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    // UNUSED, restoring is done with refreshReceipt
    /// Handles restored purchase transactions.
//    fileprivate func handleRestored(_ transaction: SKPaymentTransaction) {
//        hasRestorablePurchases = true
//        restored.append(transaction)
//        DispatchQueue.main.async {
//            self.delegate?.storeObserverRestoreDidSucceed()
//        }
//        // Finishes the restored transaction.
//        SKPaymentQueue.default().finishTransaction(transaction)
//    }

    private func validateReceipt(completionHandler: @escaping (_ result: ValidationResult, _ expires: TimeInterval?, _ product: String?, _ error: Error?) -> Void) {
        if let appStoreReceiptURL = Bundle.main.appStoreReceiptURL, FileManager.default.fileExists(atPath: appStoreReceiptURL.path) {
            do {
                let receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
                let message = [
                    "data": receiptData.base64EncodedString()
                ]
                let jsonData = try JSONSerialization.data(withJSONObject: message, options: [])
                API.shared.signedRequest(endpoint: .iosSubscription , method: .post, pubKey: try BackupManager.shared.publicKey(), privKey: try BackupManager.shared.privateKey(), body: jsonData) { (result, error) in
                    if let error = error {
                        Logger.shared.error("Error verifying receipt", error: error)
                        completionHandler(.error, nil, nil, error)
                    } else if let status = result?["status"] as? String, let validationResult = ValidationResult(rawValue: status), let expires = result?["expires"] as? TimeInterval, let product = result?["product"] as? String {
                        completionHandler(validationResult, expires, product, nil)
                    } else {
                        completionHandler(.error, nil, nil, APIError.noResponse)
                    }
                }
            } catch {
                Logger.shared.error("Couldn't read receipt data", error: error)
                completionHandler(.error, nil, nil, error)
            }
        }
    }

}

extension StoreObserver: SKRequestDelegate {

    func requestDidFinish(_ request: SKRequest) {
        handleRefreshedReceipt()
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {
            let error = error as NSError
            if error.code == 16 {
                self.delegate?.storeObserverPurchaseCancelled()
            } else {
                Logger.shared.error("Error refreshing receipt", error: error)
                self.delegate?.storeObserverDidReceiveMessage(error.localizedDescription)
            }
        }
    }
}

extension StoreObserver: SKPaymentTransactionObserver {

    //Observe transaction updates.
    func paymentQueue(_ queue: SKPaymentQueue,updatedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            switch transaction.transactionState {
            case .purchasing: break
            // Do not block your UI. Allow the user to continue using your app.
            case .deferred: print("storekit.deferred".localized)
            // The purchase was successful.
            case .purchased: handlePurchased(transaction)
            // The transaction failed.
            case .failed: handleFailed(transaction)
            // There are restored products.
            case .restored: Logger.shared.warning("Restore transaction. Should not happen")
            @unknown default: fatalError("\("storekit.unknownDefault".localized)")
            }
        }
    }

    /// Logs all transactions that have been removed from the payment queue.
    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        for transaction in transactions {
            print ("\(transaction.payment.productIdentifier) \("storekit.removed".localized)")
        }
    }

    /// Called when an error occur while restoring purchases. Notify the user about the error.
    func paymentQueue(_ queue: SKPaymentQueue, restoreCompletedTransactionsFailedWithError error: Error) {
        if let error = error as? SKError {
            print(error)
            DispatchQueue.main.async {
                if error.code == .paymentCancelled {
                    self.delegate?.storeObserverPurchaseCancelled()
                } else {
                    self.delegate?.storeObserverDidReceiveMessage(error.localizedDescription)
                }
            }
        }
    }

//    /// Called when all restorable transactions have been processed by the payment queue.
//    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
//        print("storekit.restorable".localized)
//
//        if !hasRestorablePurchases {
//            DispatchQueue.main.async {
//                self.delegate?.storeObserverDidReceiveMessage("storekit.noRestorablePurchases".localized)
//            }
//        }
//    }
}