/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest
import OneTimePassword

@testable import keyn

/*
 * Test helpers to be used in all tests.
 *
 * We cannot (easily?) create mock objects so we actually modify the Keychain, storage etc.
 *
 * Testing whether function don't throw an error is done by making the test throw the error
 * because XCTAssertNoThrow() does not check for our type of errors.
 */
class TestHelper {

    static let mnemonic = "protect twenty coach stairs picnic give patient awkward crisp option faint resemble"
    static let browserPrivateKey = try! Crypto.shared.convertFromBase64(from: "B0CyLVnG5ktYVaulLmu0YaLeTKgO7Qz16qnwLU0L904")
    static let pairingQueuePrivKey = "jlbhdgtIotiW6A20rnzkdFE87i83NaNI42rZnHLbihE"
    static let browserPublicKeyBase64 = "YlxYz86OpYfogynw-aowbLwqVsPb7OVykpEx5y1VzBQ"
    static let sessionID = "50426461766b8f7adf0800400cde997d51b5c67c493a2d12696235bd00efd5b0"
    static let linkedInPPDHandle = "c53526a0b5fc33cb7d089d53a45a76044ed5f4aea170956d5799d01b2478cdfa"

    static func setUp() {
        createSeed()
    }

    static func tearDown() {
        Session.deleteAll()
        Account.deleteAll()
        try? Seed.delete()
    }

    static func setUpBackupManager() {
        try! BackupManager.shared.initialize(completion: { (res) in })
    }

    static func tearDownBackupManager() {
        BackupManager.shared.deleteAllKeys()
    }

    private static func createSeed() {
        try? Seed.delete()

        var mnemonicArray = [String]()
        for word in mnemonic.split(separator: " ") {
            mnemonicArray.append(String(word))
        }

        let _ = try! Seed.recover(mnemonic: mnemonicArray)

        try! BackupManager.shared.initialize(completion: { (res) in })
    }
    
    static func createSession() {
        do {
            let _ = try Session.initiate(pairingQueuePrivKey: pairingQueuePrivKey, browserPubKey: browserPublicKeyBase64, browser: "Chrome", os: "MacOS")
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
            let session = try Session.get(id: sessionID)!
            let messageData = message.data(using: .utf8)!
            let sharedKey = try TestHelper.sharedKey(for: session)
            let ciphertext = try Crypto.shared.encrypt(messageData, key: sharedKey)
            return try Crypto.shared.convertToBase64(from: ciphertext)
        } catch {
            print("Cannot fake browser encryption, tests will fail: \(error)")
        }

        return nil
    }
    
    static var testSite: Site {
        let testPPD = examplePPD(minLength: 8, maxLength: 32)
        return Site(name: "Example", id: "example.com".sha256, url: "example.com", ppd: testPPD)
    }

    static func examplePPD(minLength: Int?, maxLength: Int?, maxConsecutive: Int? = nil, characterSetSettings: [PPDCharacterSetSettings]? = nil, positionRestrictions: [PPDPositionRestriction]? = nil, requirementGroups: [PPDRequirementGroup]? = nil) -> PPD {
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

    static func token() -> Token {
        let url = URL(string: "otpauth://hotp/Test:Test?secret=s2b3spmb7e3zlpzwsf5r7qylttrf45lbdgn3fyxm6cwqx2qlrixg2vgi&amp;algorithm=SHA256&amp;digits=6&amp;period=30&amp;counter=0")
        let token = Token(url: url!)
        return token!
    }

    static func sharedKey(for session: Session) throws -> Data {
        let id = "\(session.id)-io.keyn.session.shared"
        let service = "io.keyn.session.shared"
        return try Keychain.shared.get(id: id, service: service)
    }

}
