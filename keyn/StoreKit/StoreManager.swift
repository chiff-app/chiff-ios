/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import StoreKit
import Foundation

// MARK: - StoreManagerDelegate

protocol StoreManagerDelegate: AnyObject {
    /// Provides the delegate with the App Store's response.
    func storeManagerDidReceiveResponse()

    /// Provides the delegate with the error encountered during the product request.
    func storeManagerDidReceiveMessage(_ message: String)
}

// MARK: - StoreManager

class StoreManager: NSObject {
    // MARK: - Types

    static let shared = StoreManager()

    // MARK: - Properties

    /// Keeps track of all valid products. These products are available for sale in the App Store.
    var availableProducts = [SKProduct]()

    /// Keeps a strong reference to the product request.
    fileprivate var productRequest: SKProductsRequest!

    weak var delegate: StoreManagerDelegate?

    // MARK: - Initializer

    private override init() {}

    // MARK: - Request Product Information

    /// Starts the product request with the specified identifiers.
    func startProductRequest() {
        guard let identifiers = ProductIdentifiers().identifiers else {
            // TODO: Log this or show?
            return
        }
        fetchProducts(matchingIdentifiers: identifiers)
    }

    /// Fetches information about your products from the App Store.
    /// - Tag: FetchProductInformation
    fileprivate func fetchProducts(matchingIdentifiers identifiers: [String]) {
        // Create a set for the product identifiers.
        let productIdentifiers = Set(identifiers)

        // Initialize the product request with the above identifiers.
        productRequest = SKProductsRequest(productIdentifiers: productIdentifiers)
        productRequest.delegate = self

        // Send the request to the App Store.
        productRequest.start()
    }

    // MARK: - Helper Methods

    /// - returns: Existing product's title matching the specified product identifier.
    func title(matchingIdentifier identifier: String) -> String? {
        var title: String?
        guard !availableProducts.isEmpty else { return nil }

        // Search availableProducts for a product whose productIdentifier property matches identifier. Return its localized title when found.
        let result = availableProducts.filter({ (product: SKProduct) in product.productIdentifier == identifier })

        if !result.isEmpty {
            title = result.first!.localizedTitle
        }
        return title
    }

    /// - returns: Existing product's title associated with the specified payment transaction.
    func title(matchingPaymentTransaction transaction: SKPaymentTransaction) -> String {
        let title = self.title(matchingIdentifier: transaction.payment.productIdentifier)
        return title ?? transaction.payment.productIdentifier
    }
}

// MARK: - SKProductsRequestDelegate

/// Extends StoreManager to conform to SKProductsRequestDelegate.
extension StoreManager: SKProductsRequestDelegate {
    /// Used to get the App Store's response to your request and notify your observer.
    /// - Tag: ProductRequest
    func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if !response.invalidProductIdentifiers.isEmpty {
            Logger.shared.warning("Invalid products", error: nil, userInfo: ["products": response.invalidProductIdentifiers.joined(separator: ", ")])
        }

        if !response.products.isEmpty {
            availableProducts = response.products
            DispatchQueue.main.async {
                self.delegate?.storeManagerDidReceiveResponse()
            }
        }
    }
}

// MARK: - SKRequestDelegate

/// Extends StoreManager to conform to SKRequestDelegate.
extension StoreManager: SKRequestDelegate {
    /// Called when the product request failed.
    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {
            self.delegate?.storeManagerDidReceiveMessage(error.localizedDescription)
        }
    }
}
