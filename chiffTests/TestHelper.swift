//
//  TestHelper.swift
//  chiffTests
//
//  Copyright: see LICENSE.md
//

import XCTest
import OneTimePassword
import LocalAuthentication
import ChiffCore

@testable import chiff

/*
 * Test helpers can be used in all tests.
 *
 * We cannot (easily?) create mock objects so we actually modify the Keychain, storage etc.
 *
 * Testing whether function don't throw an error is done by making the test throw the error
 * because XCTAssertNoThrow() does not check for our type of errors.
 */
class TestHelper {

    static let base64seed = "_jx16O6LVpESsOBBrR2btg"
    static let passwordSeed = "L0y8UIj15Tl2jm2k5cZU8avW45GzOQi4kpHD-PdrAT0"
    static let backupSeed = "bOqw6X0TH1Xp5jh9eX2KkoLX6wDsgqbFg5-E-cJhAYw"
    static let backupPubKey = "Sv83e1XwETq4-buTc9fU29lHxCoRPlxA8Xr2pxnXQdI"
    static let backupPrivKey = "bOqw6X0TH1Xp5jh9eX2KkoLX6wDsgqbFg5-E-cJhAYxK_zd7VfAROrj5u5Nz19Tb2UfEKhE-XEDxevanGddB0g"

    static func createEmptySeed() {
        let access = SecAccessControlCreateWithFlags(nil, // Use the default allocator.
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            nil) // Ignore any error.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: KeyIdentifier.master.identifier(for: .seed),
            kSecAttrService as String: KeychainService.seed.service,
            kSecAttrAccessGroup as String: KeychainService.seed.accessGroup,
            kSecAttrAccessControl as String: access as Any]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == noErr else { fatalError(String(status)) }
    }

    static func createSeed() {
        deleteLocalData()
        guard let seed = base64seed.fromBase64, let passwordSeed = passwordSeed.fromBase64, let backupSeed = backupSeed.fromBase64 else {
            fatalError("Unable to get data from base 64 string")
        }
        guard let pubKey = TestHelper.backupPubKey.fromBase64, let privKey = TestHelper.backupPrivKey.fromBase64, let encryptionKey = "Qpx3K996cCvM4L7iZeGjHHDy2m1p0m3MTI7VRN9LrAk".fromBase64 else {
            fatalError("Unable to get data from base 64 string")
        }
        do {
            try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: seed)
            try Keychain.shared.save(id: KeyIdentifier.password.identifier(for: .seed), service: .seed, secretData: passwordSeed)
            try Keychain.shared.save(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, secretData: backupSeed)
            try Keychain.shared.save(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup, secretData: pubKey)
            try Keychain.shared.save(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup, secretData: privKey)
            try Keychain.shared.save(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup, secretData: encryptionKey)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    static func deleteLocalData() {
        BrowserSession.purgeSessionDataFromKeychain()
        UserAccount.deleteAll()
        Seed.delete(includeSeed: true)
        NotificationManager.shared.deleteKeys()
        // Wipe the keychain, keychain tests do not work without this
        let secItemClasses =  [kSecClassGenericPassword, kSecClassInternetPassword, kSecClassCertificate, kSecClassKey, kSecClassIdentity]
        for itemClass in secItemClasses {
            let spec: NSDictionary = [kSecClass: itemClass]
            SecItemDelete(spec)
        }
    }

}
