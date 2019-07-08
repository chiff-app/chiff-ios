/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import StoreKit

// MARK: - StoreObserverDelegate

protocol StoreObserverDelegate: AnyObject {
    /// Tells the delegate that the restore operation was successful.
    func storeObserverRestoreDidSucceed()

    /// Provides the delegate with messages.
    func storeObserverDidReceiveMessage(_ message: String)
}

class StoreObserver: NSObject {

    static let shared = StoreObserver()

    /// Keeps track of all purchases.
    var purchased = [SKPaymentTransaction]()

    /// Keeps track of all restored purchases.
    var restored = [SKPaymentTransaction]()

    /// Indicates whether there are restorable purchases.
    fileprivate var hasRestorablePurchases = false

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

    // MARK: - Handle Payment Transactions

    /// Handles successful purchase transactions.
    fileprivate func handlePurchased(_ transaction: SKPaymentTransaction) {
        purchased.append(transaction)
        print("\("storekit.deliverContent".localized) \(transaction.payment.productIdentifier).")
        // TODO: Here, Keyn should be unlocked and remain unlocked until further notice.
        Properties.isUnlimited = true
        // Finish the successful transaction.
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    /// Handles failed purchase transactions.
    fileprivate func handleFailed(_ transaction: SKPaymentTransaction) {
        var message = "\("storekit.purchaseOf".localized) \(transaction.payment.productIdentifier) \("storekit.failed".localized)"

        if let error = transaction.error {
            message += "\n\("storekit.error".localized) \(error.localizedDescription)"
            print("\("storekit.error".localized) \(error.localizedDescription)")
        }

        // Do not send any notifications when the user cancels the purchase.
        if (transaction.error as? SKError)?.code != .paymentCancelled {
            DispatchQueue.main.async {
                self.delegate?.storeObserverDidReceiveMessage(message)
            }
        }
        // Finish the failed transaction.
        SKPaymentQueue.default().finishTransaction(transaction)
    }

    /// Handles restored purchase transactions.
    fileprivate func handleRestored(_ transaction: SKPaymentTransaction) {
        hasRestorablePurchases = true
        restored.append(transaction)
        print("\("storekit.restoreContent".localized) \(transaction.payment.productIdentifier).")
        Properties.isUnlimited = true
        DispatchQueue.main.async {
            self.delegate?.storeObserverRestoreDidSucceed()
        }
        // Finishes the restored transaction.
        SKPaymentQueue.default().finishTransaction(transaction)
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
            case .restored: handleRestored(transaction)
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
        if let error = error as? SKError, error.code != .paymentCancelled {
            DispatchQueue.main.async {
                self.delegate?.storeObserverDidReceiveMessage(error.localizedDescription)
            }
        }
    }

    /// Called when all restorable transactions have been processed by the payment queue.
    func paymentQueueRestoreCompletedTransactionsFinished(_ queue: SKPaymentQueue) {
        print("storekit.restorable".localized)

        if !hasRestorablePurchases {
            DispatchQueue.main.async {
                self.delegate?.storeObserverDidReceiveMessage("storekit.noRestorablePurchases".localized)
            }
        }
    }
}
