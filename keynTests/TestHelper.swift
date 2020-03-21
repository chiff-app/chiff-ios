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

    static let base64seed = "_jx16O6LVpESsOBBrR2btg"
    static let CRYPTO_CONTEXT = "keynseed"
    static let passwordSeed = "L0y8UIj15Tl2jm2k5cZU8avW45GzOQi4kpHD-PdrAT0"
    static let backupSeed = "bOqw6X0TH1Xp5jh9eX2KkoLX6wDsgqbFg5-E-cJhAYw"
    static let backupPubKey = "Sv83e1XwETq4-buTc9fU29lHxCoRPlxA8Xr2pxnXQdI"
    static let backupPrivKey = "bOqw6X0TH1Xp5jh9eX2KkoLX6wDsgqbFg5-E-cJhAYxK_zd7VfAROrj5u5Nz19Tb2UfEKhE-XEDxevanGddB0g"
    static let pairingQueueSeed = "0F5l3RTX8f0TUpC9aBe-dgOwzMqaPrjPGTmh60LULFs"
    static let browserPublicKeyBase64 = "uQ-JTC6gejxrz2dNw1sXO6JAQP32wNpXFPnJ2PgksuM"
    static let sessionID = "9d710842c9cc6df1b2f4f3ca2074bc1408e525e7ce46635ce21579c9fe6f01e7"
    static let linkedInPPDHandle = "c53526a0b5fc33cb7d089d53a45a76044ed5f4aea170956d5799d01b2478cdfa"
    static let sharedKey = "msDAsyo_SFR0ixECH5zIM-X0aP87vKktwzeuH2r0A9M"
    static let sharedPrivKey = "msDAsyo_SFR0ixECH5zIM-X0aP87vKktwzeuH2r0A9Nqcmit-ItzXCWC5AhVThDcqACzW0bbSXepc9rqiCLthQ"
    static let sharedPubKey = "anJorfiLc1wlguQIVU4Q3KgAs1tG20l3qXPa6ogi7YU"
    static let hotpURL: URL! = URL(string: "otpauth://hotp/Test:Test?secret=s2b3spmb7e3zlpzwsf5r7qylttrf45lbdgn3fyxm6cwqx2qlrixg2vgi&algorithm=SHA256&digits=6&period=30&counter=0")
    static let sharedKeyID = "4a53a184604181436f8f3f7c1ff1b5bf52bdee807c61d000b53fdf4e09c9a5eb-shared"
    static let signingPrivKeyID = "4a53a184604181436f8f3f7c1ff1b5bf52bdee807c61d000b53fdf4e09c9a5eb-signing"
    static let keynRequestEncrypted = "nzLY8eBUZgQ4WYILTebsRVHGu12Tx3w85A6GXk6M-p0wNFZhPwkfTZctlOyQQ6Y-PKk_ghKpbKhW2p7M8syYr344UEQCjiaZxXocdz7r9PjnJ-ZE8kfye6-8XXZu1qbA4YedY02m92AWYftv_lFCj7v_9tX_4Co571F_muLaW6JVrKZrNz9XXlaf4WcrSu_id9zG3kGAlc-sztITZv-5_lHsrb58ffaOApl-v1kO5g8p4YUhbGKvDqxBq2ci0tAA4QqYPL42l4C4m6YLtH55GCEK5i3NwnsUZDeMH40x-H662I2gCjv6qNdvJ9MG4Sr9B8hDkrs9YUZA7swrpMWhkx4-TBlptOgNcbf8cUoGcDrJmRJ8ca69ZO7__zoEKIp2Q-Ev_sGICl9URggw7ZJgtC8iB2NTqj5448hmB7e04dB_DrOIjKl-q3ire7eqSj3Nn0IlynazMMsn2DcEtEOLKyPHuqwbeq6mRn2QHWUnRiHkCIsYdN3DFZ2p7ao"
    static let keynRequest = KeynRequest(accountID: TestHelper.userID, browserTab: 0, challenge: "tnlOysO9SoL_PAXiEuqgSNZdnZ_BfJ_ri_9UnF4B5nM", password: "[jh6eAX)og7A#nJ1:YDSrD6#61cf${\"A", passwordSuccessfullyChanged: false, siteID: TestHelper.sampleSite.id, siteName: TestHelper.sampleSite.name, siteURL: TestHelper.sampleSite.url, type: .add, relyingPartyId: "test.com", algorithms: nil, username: TestHelper.username, sentTimestamp: TimeInterval(), count: 0, sessionID: TestHelper.sessionID, accounts: nil) // Challenge is SHA256({"challenge":"3rEAfh7LQeqrLBiQjZM5284v54xIWEWV-tGOulwoDTE","clientExtensions":{},"hashAlgorithm":"SHA-256","origin":"http://localhost:9005","type":"webauthn.get"})
    static let userID = "ed98282a25e0ee58019d15523ad779bc27f2c84a73a3d43ae38acbeeede1988e"
    static let username = "test@keyn.com"
    static let userData = "ZhOIrj7miy4fkGUtLE8-hMCcc9QHpvMqfvwUvS5qhwTzG-2DDq6tHWO17tKDNnNzE3XL-0HxWkAK8kXz__M_OYQ24Yci2hyBdW1xxTx1TDErSRokfkIbrneo6HIoHWoY7tmEfg8kOq3OY8iX3LkFxDAwW01_R_MCxS5xMhQLm_f_4XTsTmWP5mVZgPK8fc0MEW7u7YfGxZHuvHsseadb4gKrIHk7_Xtemg4bjLaxqh1POza_O7rZP2Q9wBKOLPMBp7MMOF41QQrdN-5MGVDnP7wJ3rKjnSLkhuSRxxVOGYUDyo-qLksoJ_D-TkO2zk8lDgnBQa43HPG9cbqNMW59dtsj4jE6JWaEU8zcqPGx54E5nzJzGrkGT1b9Q6llG4g8qfL-N1Cy_wmwGMHLdJfi0pFGcPURtsgs8Jbq4TbWEPwDavKvNHDJRaDYT-3umgJKR4CyYeovhWAuQphOeW7Zan6AtFEFI8nJXthiR90UN6CGPdOywrZhSIpC2yhwMhDQeViCM2S6FV_IpnT7D7CbkdVJko6DBuEpr3F2kw-CMPre5GRXsdaqXyY5bhqOWL074UrT3Y-HX3Uz7Zsc_3mMBUiP0ClrVScEHbeZ5VgtIJ9G-I1AwiW3fbxTYNXA0wE1Pxy5uvOtBqZ73R8Ow7fZOYMPEazNYDU-4CpGGMc1bP11BchC6MHPIjVMgwsiO5bpuNMTiAynTL8T5EGFXkHjAh-a0phSfM2B46hgwlRbFebQOlMz0isuaf4HxnxuRvdSnbAOnUFTIKuwPKYxF15qTj6qS7cluuVEHYde7HNeV_Ey70Jgd06ECkk59EqtmBV0gO0Y6rSeHWsQvAIZwmUkkgYCH4NTmpi4c6KkTyefRINeFSi_5Gah8-MCM7OD_OC3sdCuFBQBi6gSMcDEZg_khySRrFBSk1aUA2z7pEl9N0CLOrxQt-_7nRWxgiBZ7t1pxZ0yyQ7bVUhNdrdBdmoaaw-SNvOatOWDy0OCFQJvdKKrahPUwaEmc_P9cAnb-dznfQJHS8UCMiNvIUmx7UHPA_NvKq6gn9_9gUN00g"
    static let mnemonic = ["wreck", "together", "kick", "tackle", "rely", "embrace", "enlist", "bright", "double", "happy", "group", "hope"]
    static let backupData = "eyJwYXNzd29yZEluZGV4IjowLCJlbmFibGVkIjpmYWxzZSwiaWQiOiJlZDk4MjgyYTI1ZTBlZTU4MDE5ZDE1NTIzYWQ3NzliYzI3ZjJjODRhNzNhM2Q0M2FlMzhhY2JlZWVkZTE5ODhlIiwibGFzdFBhc3N3b3JkVXBkYXRlVHJ5SW5kZXgiOjAsInVzZXJuYW1lIjoidGVzdEBrZXluLmNvbSIsInZlcnNpb24iOjEsInNpdGVzIjpbeyJpZCI6ImEzNzlhNmY2ZWVhZmI5YTU1ZTM3OGMxMTgwMzRlMjc1MWU2ODJmYWI5ZjJkMzBhYjEzZDIxMjU1ODZjZTE5NDciLCJuYW1lIjoiRXhhbXBsZSIsInVybCI6ImV4YW1wbGUuY29tIiwicHBkIjp7ImNoYXJhY3RlclNldHMiOlt7ImJhc2UiOltdLCJjaGFyYWN0ZXJzIjoiYWJjZGVmZ2hpamtsbW5vcHFyc3R1dnd4eXoiLCJuYW1lIjoiTG93ZXJMZXR0ZXJzIn0seyJiYXNlIjpbXSwiY2hhcmFjdGVycyI6IkFCQ0RFRkdISUpLTE1OT1BRUlNUVVZXWFlaIiwibmFtZSI6IlVwcGVyTGV0dGVycyJ9LHsiYmFzZSI6W10sImNoYXJhY3RlcnMiOiIwMTIzNDU2Nzg5IiwibmFtZSI6Ik51bWJlcnMifSx7ImJhc2UiOltdLCJjaGFyYWN0ZXJzIjoiKSgqJl4lJCNAIXt9W106O1wiJz9cLywuPD5gfnwiLCJuYW1lIjoiU3BlY2lhbHMifV0sInByb3BlcnRpZXMiOnsibWF4TGVuZ3RoIjozMiwiZXhwaXJlcyI6MCwibWluTGVuZ3RoIjo4fSwidGltZXN0YW1wIjo1ODk4NTYzODYuODMxMjIwOTgsInVybCI6Imh0dHBzOlwvXC9leGFtcGxlLmNvbSIsIm5hbWUiOiJFeGFtcGxlIiwidmVyc2lvbiI6IjEuMCJ9fV19"

    static var sampleSite: Site {
        let testPPD = samplePPD(minLength: 8, maxLength: 32)
        return Site(name: "Example", id: "example.com".sha256, url: "example.com", ppd: testPPD)
    }

    static var sampleSiteV1_1: Site {
        let testPPD = samplePPDV1_1(minLength: 8, maxLength: 32)
        return Site(name: "Example", id: "example.com".sha256, url: "example.com", ppd: testPPD)
    }

    static func samplePPD(minLength: Int?, maxLength: Int?, maxConsecutive: Int? = nil, characterSetSettings: [PPDCharacterSetSettings]? = nil, positionRestrictions: [PPDPositionRestriction]? = nil, requirementGroups: [PPDRequirementGroup]? = nil) -> PPD {
        var characterSets = [PPDCharacterSet]()
        characterSets.append(PPDCharacterSet(base: nil, characters: "abcdefghijklmnopqrstuvwxyz", name: "LowerLetters"))
        characterSets.append(PPDCharacterSet(base: nil, characters: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", name: "UpperLetters"))
        characterSets.append(PPDCharacterSet(base: nil, characters: "0123456789", name: "Numbers"))
        characterSets.append(PPDCharacterSet(base: nil, characters: ")(*&^%$#@!{}[]:;\"'?/,.<>`~|", name: "Specials"))

        var ppdCharacterSettings: PPDCharacterSettings?
        if characterSetSettings != nil || positionRestrictions != nil || requirementGroups != nil {
            ppdCharacterSettings = PPDCharacterSettings(characterSetSettings: characterSetSettings, requirementGroups: requirementGroups, positionRestrictions: positionRestrictions)
        }

        let properties = PPDProperties(characterSettings: ppdCharacterSettings, maxConsecutive: maxConsecutive, minLength: minLength, maxLength: maxLength)
        return PPD(characterSets: characterSets, properties: properties, service: nil, version: .v1_0, timestamp: Date(timeIntervalSinceNow: 0.0), url: "https://example.com", redirect: nil, name: "Example")
    }

    static func samplePPDV1_1(minLength: Int?, maxLength: Int?, maxConsecutive: Int? = nil, characterSetSettings: [PPDCharacterSetSettings]? = nil, positionRestrictions: [PPDPositionRestriction]? = nil, requirementGroups: [PPDRequirementGroup]? = nil) -> PPD {
        var characterSets = [PPDCharacterSet]()
        characterSets.append(PPDCharacterSet(base: .lowerLetters, characters: nil, name: "LowerLetters"))
        characterSets.append(PPDCharacterSet(base: .upperLetters, characters: "ABCDEFGHIJKLMNOPQRSTUVWXYZ", name: "UpperLetters"))
        characterSets.append(PPDCharacterSet(base: .numbers, characters: nil, name: "Numbers"))
        characterSets.append(PPDCharacterSet(base: .specials, characters: " ", name: "Specials"))

        var ppdCharacterSettings: PPDCharacterSettings?
        if characterSetSettings != nil || positionRestrictions != nil || requirementGroups != nil {
            ppdCharacterSettings = PPDCharacterSettings(characterSetSettings: characterSetSettings, requirementGroups: requirementGroups, positionRestrictions: positionRestrictions)
        }

        let properties = PPDProperties(characterSettings: ppdCharacterSettings, maxConsecutive: maxConsecutive, minLength: minLength, maxLength: maxLength)
        return PPD(characterSets: characterSets, properties: properties, service: nil, version: .v1_1, timestamp: Date(timeIntervalSinceNow: 0.0), url: "https://example.com", redirect: nil, name: "Example")
    }

    static func saveHOTPToken(id: String, includeData: Bool = true) {
        do {
            guard let token = Token(url: hotpURL) else {
                fatalError("Failed to create token")
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
        guard let seed = base64seed.fromBase64, let passwordSeed = passwordSeed.fromBase64, let backupSeed = backupSeed.fromBase64 else {
            fatalError("Unable to get data from base 64 string")
        }

        do {            
            try Keychain.shared.save(id: KeyIdentifier.master.identifier(for: .seed), service: .seed, secretData: seed)
            try Keychain.shared.save(id: KeyIdentifier.password.identifier(for: .seed), service: .seed, secretData: passwordSeed)
            try Keychain.shared.save(id: KeyIdentifier.backup.identifier(for: .seed), service: .seed, secretData: backupSeed)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    static func createBackupKeys() {
        guard let pubKey = TestHelper.backupPubKey.fromBase64, let privKey = TestHelper.backupPrivKey.fromBase64, let encryptionKey = "Qpx3K996cCvM4L7iZeGjHHDy2m1p0m3MTI7VRN9LrAk".fromBase64 else {
            fatalError("Unable to get data from base 64 string")
        }
        do {
            try Keychain.shared.save(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup, secretData: pubKey)
            try Keychain.shared.save(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup, secretData: privKey)
            try Keychain.shared.save(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup, secretData: encryptionKey)
        } catch {
            fatalError(error.localizedDescription)
        }
    }
    
    static func createEndpointKey() {
        do {
            try Keychain.shared.save(id: KeyIdentifier.endpoint.identifier(for: .aws), service: .aws, secretData: sessionID.data)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    static func createSharedKey() -> (Data, Data, Data) {
        guard let sharedKey = TestHelper.sharedKey.fromBase64, let privKey = TestHelper.sharedPrivKey.fromBase64, let pubKey = TestHelper.sharedPubKey.fromBase64 else {
            fatalError("Error getting data from base64 string")
        }
        do {
            // This inserts an invalid entry in the Keychain, because there is no objectData
            try Keychain.shared.save(id: sharedKeyID, service: .sharedSessionKey, secretData: sharedKey)
            try Keychain.shared.save(id: signingPrivKeyID, service: .signingSessionKey, secretData: privKey)
            return (sharedKey, privKey, pubKey)
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    static func createSessionInKeychain() -> Session {
        guard let sharedKey = TestHelper.sharedKey.fromBase64, let privKey = TestHelper.sharedPrivKey.fromBase64, let pubKey = TestHelper.sharedPubKey.fromBase64 else {
            fatalError("Error getting data from base64 string")
        }
        do {
            let session = BrowserSession(id: sessionID, signingPubKey: pubKey, browser: .chrome, title: "Chrome @ test", version: 0)
            let encoder = PropertyListEncoder()
            try Keychain.shared.save(id: sharedKeyID, service: .sharedSessionKey, secretData: sharedKey, objectData: encoder.encode(session))
            try Keychain.shared.save(id: signingPrivKeyID, service: .signingSessionKey, secretData: privKey)
            return session
        } catch {
            fatalError(error.localizedDescription)
        }
    }

    static func deleteLocalData() {
        let _ = BrowserSession.deleteAll()
        UserAccount.deleteAll()
        Seed.delete()
        NotificationManager.shared.deleteEndpoint()
        NotificationManager.shared.deleteKeys()
        BackupManager.deleteKeys()
        // Wipe the keychain, keychain tests do not work without this
        let secItemClasses =  [kSecClassGenericPassword, kSecClassInternetPassword, kSecClassCertificate, kSecClassKey, kSecClassIdentity]
        for itemClass in secItemClasses {
            let spec: NSDictionary = [kSecClass: itemClass]
            SecItemDelete(spec)
        }
    }

}
