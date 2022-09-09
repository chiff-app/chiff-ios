//
//  Keychain+SecKey.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import Security
import LocalAuthentication
import CryptoKit
import PromiseKit

/// The interface needed for SecKey conversion.
public protocol SecKeyConvertible: CustomStringConvertible {
    /// Creates a key from an X9.63 representation.
    init<Bytes>(x963Representation: Bytes) throws where Bytes: ContiguousBytes

    /// An X9.63 representation of the key.
    var x963Representation: Data { get }
}

extension SecKeyConvertible {
    /// A string version of the key for visual inspection.
    /// IMPORTANT: Never log the actual key data.
    public var description: String {
        return self.x963Representation.withUnsafeBytes { bytes in
            return "Key representation contains \(bytes.count) bytes."
        }
    }
}

// Assert that the NIST keys are convertible.
@available(iOS 13.0, *) extension P256.Signing.PrivateKey: SecKeyConvertible {}
@available(iOS 13.0, *) extension P256.KeyAgreement.PrivateKey: SecKeyConvertible {}
@available(iOS 13.0, *) extension P384.Signing.PrivateKey: SecKeyConvertible {}
@available(iOS 13.0, *) extension P384.KeyAgreement.PrivateKey: SecKeyConvertible {}
@available(iOS 13.0, *) extension P521.Signing.PrivateKey: SecKeyConvertible {}
@available(iOS 13.0, *) extension P521.KeyAgreement.PrivateKey: SecKeyConvertible {}

public extension Keychain {

    // MARK: - SecKey operations

    func saveKey<T: SecKeyConvertible>(id identifier: String, key: T) throws {
        // Describe the key.
        let attributes = [kSecAttrKeyType: kSecAttrKeyTypeECSECPrimeRandom,
                          kSecAttrAccessGroup: KeychainService.account(attribute: .webauthn).accessGroup,
                          kSecAttrKeyClass: kSecAttrKeyClassPrivate] as [String: Any]

        // Get a SecKey representation.
        guard let secKey = SecKeyCreateWithData(key.x963Representation as CFData, attributes as CFDictionary, nil) else {
            throw KeychainError.createSecKey
        }

        let access = SecAccessControlCreateWithFlags(nil, // Use the default allocator.
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            nil) // Ignore any error.

        // Describe the add operation.
        let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                    kSecAttrAccessControl as String: access as Any,
                                    kSecAttrApplicationLabel as String: identifier,
                                    kSecValueRef as String: secKey]

        // Add the key to the keychain.
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeychainError.unhandledError(status.message)
        }
    }

    @available(iOS 13.0, *)
    func getKey<T: SecKeyConvertible>(id identifier: String, context: LAContext?) throws -> T? {

        // Seek an elliptic-curve key with a given label.
        let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                    kSecAttrApplicationLabel as String: identifier,
                                    kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
                                    kSecUseAuthenticationContext as String: context ?? LocalAuthenticationManager.shared.mainContext,
                                    kSecReturnRef as String: true]

        // Find and cast the result as a SecKey instance.
        var item: CFTypeRef?
        var secKey: SecKey
        switch SecItemCopyMatching(query as CFDictionary, &item) {
        case errSecSuccess: secKey = item as! SecKey  // swiftlint:disable:this force_cast
        case errSecItemNotFound: return nil
        case errSecInteractionNotAllowed: throw KeychainError.interactionNotAllowed
        case let status: throw KeychainError.unhandledError(status.message)
        }

        // Convert the SecKey into a CryptoKit key.
        var error: Unmanaged<CFError>?
        guard let data = SecKeyCopyExternalRepresentation(secKey, &error) as Data? else {
            throw KeychainError.unexpectedData
        }
        return try T(x963Representation: data)
    }

    func deleteKey(id identifier: String) throws {
        let query: [String: Any] = [kSecClass as String: kSecClassKey,
                                    kSecAttrApplicationLabel as String: identifier]

        switch SecItemDelete(query as CFDictionary) {
        case errSecSuccess: break
        case errSecItemNotFound:
            throw KeychainError.notFound
        case let status:
            throw KeychainError.unhandledError(status.message)
        }
    }

    func deleteAllKeys() {
        let query: [String: Any] = [kSecClass as String: kSecClassKey]
        SecItemDelete(query as CFDictionary)
    }

}
