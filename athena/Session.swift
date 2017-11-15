//
//  Session.swift
//  athena
//
//  Created by bas on 13/11/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import Foundation


struct Session: Codable {
    let sqsURL: String
    let nonce: String
    let keyIdentifier: String


    enum KeyError: Error {
        case base64Decoding
        case storeKey
    }

    init(sqs: String, nonce: String, pubKey: String)  {
        // TODO: This doesn't work with decoding JSON string, check https://developer.apple.com/documentation/foundation/archives_and_serialization/encoding_and_decoding_custom_types
        self.sqsURL = sqs
        self.nonce = nonce
        let keyIdentifier = (sqsURL + nonce).sha256()
        self.keyIdentifier = keyIdentifier.substring(to: keyIdentifier.index(keyIdentifier.startIndex, offsetBy: 8))
        do {
            try importPublicKey(from: pubKey, to: self.keyIdentifier)
        } catch {
            print(error)
        }
    }

    func importPublicKey(from base64EncodedKey: String, to uniqueIdentifier: String) throws {
        // Convert from base64 to Data

        guard let pkData = Data.init(base64Encoded: base64EncodedKey) else {
            throw KeyError.base64Decoding
        }

        // Create SecKey item

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeECSECPrimeRandom,
            kSecAttrKeyClass as String: kSecAttrKeyClassPublic,
            kSecAttrKeySizeInBits as String: 256
        ]

        var error: Unmanaged<CFError>?

        guard let publicKey = SecKeyCreateWithData(pkData as CFData, attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }

        // Store key

        let tag = "com.athena.keys.\(uniqueIdentifier)".data(using: .utf8)!
        let addquery: [String: Any] = [kSecClass as String: kSecClassKey,
                                       kSecAttrApplicationTag as String: tag,
                                       kSecValueRef as String: publicKey]

        let status = SecItemAdd(addquery as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw KeyError.storeKey
        }
    }

}
