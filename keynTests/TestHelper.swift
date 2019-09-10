/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest
import OneTimePassword
import LocalAuthentication

@testable import keyn

/*
 * Test helpers can be used in all tests.
 *
 * We cannot (easily?) create mock objects so we actually modify the Keychain, storage etc.
 *
 * Testing whether function don't throw an error is done by making the test throw the error
 * because XCTAssertNoThrow() does not check for our type of errors.
 */
class TestHelper {

    static let mnemonic = "wreck together kick tackle rely embrace enlist bright double happy group honey"
    static let base64seed = "_jx16O6LVpESsOBBrR2btg"
    static let pairingQueueSeed = "0F5l3RTX8f0TUpC9aBe-dgOwzMqaPrjPGTmh60LULFs"
    static let browserPublicKeyBase64 = "uQ-JTC6gejxrz2dNw1sXO6JAQP32wNpXFPnJ2PgksuM"
    static let sessionID = "9d710842c9cc6df1b2f4f3ca2074bc1408e525e7ce46635ce21579c9fe6f01e7"
    static let linkedInPPDHandle = "c53526a0b5fc33cb7d089d53a45a76044ed5f4aea170956d5799d01b2478cdfa"
    static let sharedKey = "cxwPChlS-B42jQveGPWp_Nxhtjk8a68lTZDTDSdRZAs"
    static let hotpURL: URL! = URL(string: "otpauth://hotp/Test:Test?secret=s2b3spmb7e3zlpzwsf5r7qylttrf45lbdgn3fyxm6cwqx2qlrixg2vgi&amp;algorithm=SHA256&amp;digits=6&amp;period=30&amp;counter=0")

    static var sampleSite: Site {
        let testPPD = samplePPD(minLength: 8, maxLength: 32)
        return Site(name: "Example", id: "example.com".sha256, url: "example.com", ppd: testPPD)
    }

    static func samplePPD(minLength: Int?, maxLength: Int?, maxConsecutive: Int? = nil, characterSetSettings: [PPDCharacterSetSettings]? = nil, positionRestrictions: [PPDPositionRestriction]? = nil, requirementGroups: [PPDRequirementGroup]? = nil) -> PPD {
        var characterSets = [PPDCharacterSet]()
        characterSets.append(PPDCharacterSet(base: [String](), characters: "abcdefghijklmnopqrstuvwxyz", name: "LowerLetters"))
        characterSets.append(PPDCharacterSet(base: [String](), characters: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", name: "UpperLetters"))
        characterSets.append(PPDCharacterSet(base: [String](), characters: "0123456789", name: "Numbers"))
        characterSets.append(PPDCharacterSet(base: [String](), characters: ")(*&^%$#@!{}[]:;\"'?/,.<>`~|", name: "Specials"))

        var ppdCharacterSettings: PPDCharacterSettings?
        if characterSetSettings != nil || positionRestrictions != nil || requirementGroups != nil {
            ppdCharacterSettings = PPDCharacterSettings(characterSetSettings: characterSetSettings, requirementGroups: requirementGroups, positionRestrictions: positionRestrictions)
        }

        let properties = PPDProperties(characterSettings: ppdCharacterSettings, maxConsecutive: maxConsecutive, minLength: minLength, maxLength: maxLength)
        return PPD(characterSets: characterSets, properties: properties, service: nil, version: "1.0", timestamp: Date(timeIntervalSinceNow: 0.0), url: "https://example.com", redirect: nil, name: "Example")
    }

    static func saveHOTPToken(id: String, includeData: Bool = true) {
        do {
            guard let token = Token(url: hotpURL) else {
                fatalError("Failted to create token")
            }
            let secret = token.generator.secret
            let tokenData = try token.toURL().absoluteString.data
            
            if Keychain.shared.has(id: id, service: .otp) {
                try Keychain.shared.update(id: id, service: .otp, secretData: secret, objectData: includeData ? tokenData : nil)
            } else {
                try Keychain.shared.save(id: id, service: .otp, secretData: secret, objectData: includeData ? tokenData : nil)
            }
        } catch {
            fatalError("Failed to set the OTP token")
        }
    }
    
    static func createEmptySeed() {
        let access = SecAccessControlCreateWithFlags(nil, // Use the default allocator.
            kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
            .userPresence,
            nil) // Ignore any error.
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: KeyIdentifier.master.identifier(for: .seed),
            kSecAttrService as String: KeychainService.seed.rawValue,
            kSecAttrAccessGroup as String: KeychainService.seed.accessGroup,
            kSecAttrAccessControl as String: access as Any]
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == noErr else { fatalError(String(status)) }
    }

    static func createSeed() {
        deleteLocalData()

        do {
            let seed = base64seed.fromBase64!
            let passwordSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: "keynseed")
            let backupSeed = try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .backupSeed, context: "keynseed")
            
            try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: seed)
            try Keychain.shared.save(id: KeyIdentifier.password.identifier(for: .seed), service: .seed, secretData: passwordSeed)
            try Keychain.shared.save(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, secretData: backupSeed)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    static func createBackupKeys() {
        do {
            let backupSeed = try Keychain.shared.get(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed)
            let keyPair = try Crypto.shared.createSigningKeyPair(seed: backupSeed)
            try Keychain.shared.save(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup, secretData: keyPair.pubKey)
            try Keychain.shared.save(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup, secretData: keyPair.privKey)
            
            let encryptionKey = try Crypto.shared.deriveKey(keyData: backupSeed, context: "keynback")
            try Keychain.shared.save(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup, secretData: encryptionKey)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    static func deleteLocalData() {
        Session.deleteAll()
        Account.deleteAll()
        try? Seed.delete()
        NotificationManager.shared.deleteEndpoint()
        BackupManager.shared.deleteAllKeys()
        // Wipe the keychain, keychain tests do not work without this
        let secItemClasses =  [kSecClassGenericPassword, kSecClassInternetPassword, kSecClassCertificate, kSecClassKey, kSecClassIdentity]
        for itemClass in secItemClasses {
            let spec: NSDictionary = [kSecClass: itemClass]
            SecItemDelete(spec)
        }
    }

}
