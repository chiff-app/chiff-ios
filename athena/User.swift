import Foundation

/*
 * A user has multiple accounts and one private key used for generating passwords.
 */
struct User {

    init() {
         if !self.hasPrivateKey() {
            do {
                // We will need to have some kind of transaction in which
                // the creation of the key pair and the user validation of
                // the resulting seed is done. If it fails > rollback.
                try self.createKeyPair()
                while !self.validateKeyBySeed() {
                    print("Try again man...")
                }
            } catch (let error) {
                print(error)
            }
        }
    }

    /*
     * The first time we use the app, we need to create the private key and put it in the
     * secure enclave. This function will need to be called in the setup process and from
     * the resulting private key we will need to generate a seed.
     */
    func createKeyPair() throws {
        let accessControl =
            SecAccessControlCreateWithFlags(kCFAllocatorDefault,
                                            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
                                            // TODO: Find optimal parameters for security/usability here.
                                            [.privateKeyUsage, .userPresence],
                                            nil)! // TODO: Ignore error or check it?

        let attributes: [String: Any] = [
            kSecAttrKeyType as String: kSecAttrKeyTypeEC,
            kSecAttrKeySizeInBits as String: 256,
            kSecAttrTokenID as String: kSecAttrTokenIDSecureEnclave,
            kSecPrivateKeyAttrs as String: [
                kSecAttrIsPermanent as String: true,
                kSecAttrApplicationTag as String: "AthenaPrivateKey", // TODO: Check if this needs to be a namespaced identifier.
                kSecAttrAccessControl as String: accessControl
            ]
        ]

        var error: Unmanaged<CFError>?
        guard let privateKey = SecKeyCreateRandomKey(attributes as CFDictionary, &error) else {
            throw error!.takeRetainedValue() as Error
        }

        print(privateKey)
    }

    /*
     * Check whether this is a new user. Maybe store this in regular
     * storage or check the secure enclave for the presence of "AthenaPrivateKey"
     */
    func hasPrivateKey() -> Bool {
        return true
    }

    /*
     * Not sure if this is the best place for this function but the
     * user has to validate the private key by means of entering
     * a few words of the seed.
     */
    func validateKeyBySeed() -> Bool {
        return true
    }

}
