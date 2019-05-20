/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import StoreKit

class StoreObserver: NSObject, SKPaymentTransactionObserver {

    static let shared = StoreObserver()

    var isAuthorizedForPayments: Bool {
        return SKPaymentQueue.canMakePayments()
    }

    func enable() {
        SKPaymentQueue.default().add(self)
    }

    func disable() {
        SKPaymentQueue.default().remove(self)
    }

    //Observe transaction updates.
    func paymentQueue(_ queue: SKPaymentQueue,updatedTransactions transactions: [SKPaymentTransaction]) {
        //Handle transaction states here.
    }
}
