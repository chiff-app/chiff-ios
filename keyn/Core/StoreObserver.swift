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


    //Observe transaction updates.
    func paymentQueue(_ queue: SKPaymentQueue,updatedTransactions transactions: [SKPaymentTransaction]) {
        //Handle transaction states here.
    }
}
