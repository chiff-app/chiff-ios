/*
 * Example of keypair generation. Will only work on phone so it seems.
 */
import UIKit


let accessControl =
    SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                    kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                    [.privateKeyUsage, .userPresence],
                                    nil)! // Ignore error

let attributes: [String: Any] = [
    kSecAttrKeyType as String: kSecAttrKeyTypeEC,
    kSecAttrKeySizeInBits as String: 256,
    kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
    kSecPrivateKeyAttrs as String: [
        kSecAttrIsPermanent as String: true,
        kSecAttrApplicationTag as String: "AthenaPrivateKey",
        kSecAttrAccessControl as String: accessControl
    ]
]

var error: Unmanaged<CFError>?

guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
    print(error!.takeRetainedValue() as Error)
    throw error!.takeRetainedValue() as Error
}

print(privateKey)
print(privateKey.hashValue)
