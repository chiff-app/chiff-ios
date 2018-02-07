/*
 * Test helpers to be used in all tests.
 * We cannot (easily?) create mock objects so we actually modify the
 * Keychain, storage etc.
 */
import XCTest

@testable import keyn

class TestHelper {

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

}
