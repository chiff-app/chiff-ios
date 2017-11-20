import Foundation
import CryptoSwift

/*
 * A user has multiple accounts and one seed used for generating passwords.
 */
struct User {


    init() {
         if !self.hasSeed() {
            do {
                // We will need to have some kind of transaction in which
                // the creation of the key pair and the user validation of
                // the resulting seed is done. If it fails > rollback.
                try self.generateSeed()
                while !self.validateKeyBySeed() {
                    print("Try again man...")
                }
            } catch (let error) {
                print(error)
            }
        }
    }

    /*
     * The first time we use the app, we need to generate the seed and put it in the
     * keychain. This function will need to be called in the setup process and from
     * the resulting seed all passwords will be generated.
     */
    func generateSeed() throws {
        return try Crypto.generateSeed()
    }


    /*
     * Check whether this is a new user. Maybe store this in regular
     * storage or check the secure enclave for the presence of "AthenaPrivateKey"
     */
    func hasSeed() -> Bool {
        return Keychain.hasSeed()
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
