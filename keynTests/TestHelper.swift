/*
 * Test helpers to be used in all tests.
 * We cannot (easily?) create mock objects so we actually modify the
 * Keychain, storage etc.
 */
import XCTest

@testable import keyn

class TestHelper {

    static let browserPrivateKey = try! Crypto.sharedInstance.convertFromBase64(from: "yQ3untNLy-DnV8WxCissyK4mfrlZ8QHiowG-QnWNCEI")
    static let browserPublicKeyBase64 = "tq08gf3SIKaBlmGiQY0p66gmI7utU3kLHyKEP2t343s"


    static func deleteSessionKeys() {
        // Remove passwords
        let query: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                    kSecAttrService as String: "io.keyn.session.browser"]

        // Try to delete the seed if it exists.
        let status = SecItemDelete(query as CFDictionary)

        if status == errSecItemNotFound { print("No browser sessions found") } else {
            print(status)
        }

        // Remove passwords
        let query2: [String: Any] = [kSecClass as String: kSecClassGenericPassword,
                                     kSecAttrService as String: "io.keyn.session.app"]

        // Try to delete the seed if it exists.
        let status2 = SecItemDelete(query2 as CFDictionary)

        if status2 == errSecItemNotFound { print("No own sessions keys found") } else {
            print(status2)
        }
    }

    static func createSession() -> String? {
        do {
            let session = try Session(sqs: "sqs", browserPublicKey: browserPublicKeyBase64,
                                      browser: "browser", os: "OS")
            return session.id
        } catch {
            print("Cannot create session, tests will fail: \(error)")
        }

        return nil
    }

    static func encryptAsBrowser(_ message: String, _ sessionID: String) -> String? {
        do {
            let session = try Session.getSession(id: sessionID)!
            let appPublicKey: Data = try session.appPublicKey()
            let messageData = message.data(using: .utf8)!
            let ciphertext = try Crypto.sharedInstance.encrypt(messageData, pubKey: appPublicKey, privKey: browserPrivateKey)

            return try Crypto.sharedInstance.convertToBase64(from: ciphertext)
        } catch {
            print("Cannot fake browser encryption, tests will fail: \(error)")
        }

        return nil
    }

    static func examplePasswordRestrictions() -> PasswordRestrictions {
        return PasswordRestrictions(length: 24, characters: [.lower, .numbers, .upper, .symbols])
    }

}
