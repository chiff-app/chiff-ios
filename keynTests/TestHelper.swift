/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest
import OneTimePassword

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
    static let pairingQueueSeed = "0F5l3RTX8f0TUpC9aBe-dgOwzMqaPrjPGTmh60LULFs"
    static let browserPublicKeyBase64 = "uQ-JTC6gejxrz2dNw1sXO6JAQP32wNpXFPnJ2PgksuM"
    static let sessionID = "9d710842c9cc6df1b2f4f3ca2074bc1408e525e7ce46635ce21579c9fe6f01e7"
    static let linkedInPPDHandle = "c53526a0b5fc33cb7d089d53a45a76044ed5f4aea170956d5799d01b2478cdfa"

    static func setUp() {
        tearDown()
        tearDownBackupManager()
        createSeed()
    }

    static func tearDown() {
        Session.deleteAll()
        Account.deleteAll()
        try? Seed.delete()
    }

    static func setUpBackupManager() {
        try! BackupManager.shared.initialize() { (res) in }
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

        try! BackupManager.shared.initialize() { (res) in }
    }
    
    static func createSession() {
        do {
            let session = try Session.initiate(pairingQueueSeed: pairingQueueSeed, browserPubKey: browserPublicKeyBase64, browser: "Chrome", os: "MacOS")
            print("Created session with id \(session.id)")
        } catch {
            switch error {
            case SessionError.noEndpoint:
                print("Cannot create session. There is no endpoint. Tests will fail.")
                print(error)
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
