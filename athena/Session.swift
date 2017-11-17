//
//  Session.swift
//  athena
//
//  Created by bas on 13/11/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import Foundation


struct Session {
    let sqsURL: URL
    let nonce: String
    let keyIdentifier: String


    enum KeyError: Error {
        case base64Decoding
        case storeKey
    }

    init(sqs: URL, nonce: String, pubKey: String)  {
        self.sqsURL = sqs
        self.nonce = nonce

        // TODO: How can we best determine an identifier?
        let keyIdentifier = (pubKey + sqs.absoluteString + nonce).sha256()
        let index = keyIdentifier.index(keyIdentifier.startIndex, offsetBy: 8)
        self.keyIdentifier = String(keyIdentifier[..<index])
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
