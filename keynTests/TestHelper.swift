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
    static let linkedInPPDHandle = "c53526a0b5fc33cb7d089d53a45a76044ed5f4aea170956d5799d01b2478cdfa"


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
            let session = try Session(sqsMessageQueue: "sqs", sqsControlQueue: "sqs2", browserPublicKey: browserPublicKeyBase64, browser: "browser", os: "OS")
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
    
    static func examplePPD(completionHandler: @escaping (Site) -> Void) {
        Site.get(id: linkedInPPDHandle, completion: completionHandler)
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
        return PPD(characterSets: characterSets, properties: properties, version: "1.0", timestamp: Date(timeIntervalSinceNow: 0.0), url: "https://example.com", redirect: nil, name: "Example")
    }

}
