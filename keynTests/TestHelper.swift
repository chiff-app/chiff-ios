/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest

@testable import keyn

/*
 * Test helpers to be used in all tests.
 * We cannot (easily?) create mock objects so we actually modify the Keychain, storage etc.
 */
class TestHelper {
    static let mnemonic = "protect twenty coach stairs picnic give patient awkward crisp option faint resemble"
    static let browserPrivateKey = try! Crypto.shared.convertFromBase64(from: "B0CyLVnG5ktYVaulLmu0YaLeTKgO7Qz16qnwLU0L904")
    static let browserQueueSeed = "jlbhdgtIotiW6A20rnzkdFE87i83NaNI42rZnHLbihE"
    static let browserPublicKeyBase64 = "YlxYz86OpYfogynw-aowbLwqVsPb7OVykpEx5y1VzBQ"
    static let sessionID = "50426461766b8f7adf0800400cde997d51b5c67c493a2d12696235bd00efd5b0"
    static let linkedInPPDHandle = "c53526a0b5fc33cb7d089d53a45a76044ed5f4aea170956d5799d01b2478cdfa"

    static func createSeed() {
        try? Seed.delete()

        var mnemonicArray = [String]()
        for word in mnemonic.split(separator: " ") {
            mnemonicArray.append(String(word))
        }

        try! Seed.recover(mnemonic: mnemonicArray)

        initBackup()
    }
    
    static func deleteSeed() {
        try? Seed.delete()
    }
    
    static func deinitBackup() {
        BackupManager.sharedInstance.deleteAllKeys()
    }
    
    static func initBackup() {
        try! BackupManager.sharedInstance.initialize()
    }
    
    static func resetKeyn() {
        Session.deleteAll()
        Account.deleteAll()
        try? Seed.delete()
        BackupManager.sharedInstance.deleteAllKeys()
    }

    static func createSession() {
        do {
            let _ = try Session.initiate(queueSeed: browserQueueSeed, pubKey: browserPublicKeyBase64, browser: "Chrome", os: "MacOS")
        } catch {
            switch error {
            case SessionError.noEndpoint:
                print("No endpoint because testing on simulator.")
            default:
                fatalError("Error creating session")
            }
        }
    }

    static func encryptAsBrowser(_ message: String, _ sessionID: String) -> String? {
        do {
            let session = try Session.getSession(id: sessionID)!
            let appPublicKey: Data = try session.appPublicKey()
            let messageData = message.data(using: .utf8)!
            let ciphertext = try Crypto.shared.encrypt(messageData, pubKey: appPublicKey, privKey: browserPrivateKey)

            return try Crypto.shared.convertToBase64(from: ciphertext)
        } catch {
            print("Cannot fake browser encryption, tests will fail: \(error)")
        }

        return nil
    }
    
    static func exampleSite(completionHandler: @escaping (_ site: Site?) -> Void) {
        try! Site.get(id: linkedInPPDHandle, completion: completionHandler)
    }

    static func examplePPD(maxConsecutive: Int?, minLength: Int?, maxLength: Int?, characterSetSettings: [PPDCharacterSetSettings]?, positionRestrictions: [PPDPositionRestriction]?, requirementGroups: [PPDRequirementGroup]?) -> PPD {
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
}
