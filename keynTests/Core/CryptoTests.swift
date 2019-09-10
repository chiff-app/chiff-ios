/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import XCTest
import Sodium

@testable import keyn

class CryptoTests: XCTestCase {

    func testGenerateSeedDoesntThrow() {
        XCTAssertNoThrow(try Crypto.shared.generateSeed())
    }

    func testGenerateReturnsSeedWithCorrectType() {
        do {
            let seed = try Crypto.shared.generateSeed()
            XCTAssert((seed as Any) is Data)
        } catch {
            XCTFail("Error during seed generation: \(error)")
        }
    }

    func testGenerateReturnsSeedWithCorrectLength() {
        do {
            let seed = try Crypto.shared.generateSeed()
            XCTAssertEqual(seed.count, 16)
        } catch {
            XCTFail("Error during seed generation: \(error)")
        }
    }

    func testDeriveKeyFromSeedDoesntThrow() {
        do {
            let seed = try Crypto.shared.generateSeed()
            XCTAssertNoThrow(try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: "0"))
            XCTAssertThrowsError(try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: "200000000000"))
        } catch {
            XCTFail("Error during seed generation: \(error)")
        }
    }
    
    func testDeriveKeyFromSeed() {
        guard let seed = TestHelper.base64seed.fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        XCTAssertEqual(try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: "keynseed").base64, "L0y8UIj15Tl2jm2k5cZU8avW45GzOQi4kpHD-PdrAT0")
    }
    
    func testCreateSessionKeyPairDoesntThrow() {
        XCTAssertNoThrow(try Crypto.shared.createSessionKeyPair())
    }
    
    func testCreateSigningKeyPairDoesntThrow() {
        guard let seed = "bOqw6X0TH1Xp5jh9eX2KkoLX6wDsgqbFg5-E-cJhAYw".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        XCTAssertNoThrow(try Crypto.shared.createSigningKeyPair(seed: seed))
    }
    
    func testCreateSigningKeyPairThrowsIfWrongSeed() {
        guard let seed = "asdnaslkdjn-E-cJhAYw".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        XCTAssertThrowsError(try Crypto.shared.createSigningKeyPair(seed: seed))
    }
    
    func testCreateSignInKeyPair() {
        guard let seed = "bOqw6X0TH1Xp5jh9eX2KkoLX6wDsgqbFg5-E-cJhAYw".fromBase64, let pubKey = "Sv83e1XwETq4-buTc9fU29lHxCoRPlxA8Xr2pxnXQdI".fromBase64, let privKey = "bOqw6X0TH1Xp5jh9eX2KkoLX6wDsgqbFg5-E-cJhAYxK_zd7VfAROrj5u5Nz19Tb2UfEKhE-XEDxevanGddB0g".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        do {
            let keyPair = try Crypto.shared.createSigningKeyPair(seed: seed)
            XCTAssertEqual(keyPair.pubKey, pubKey)
            XCTAssertEqual(keyPair.privKey, privKey)
        } catch {
            XCTFail("Error creating key pair: \(error)")
        }
    }
    
    func testDeterministicRandomBytes() {
        guard let seed = "L0y8UIj15Tl2jm2k5cZU8avW45GzOQi4kpHD-PdrAT0".fromBase64, let wrongSeed = "lasjndkjsnk".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        do {
            let data = try Crypto.shared.deterministicRandomBytes(seed: seed, length: 64)
            XCTAssertEqual(data.count, 64)
            XCTAssertEqual(data.base64, "-ouKUXID1ysH-RP7YIRlcDoWR3nTz-nu6Nr9g9sRrX-XhvIXDmao8hpUHU4y_BUGSrAg9ADQfzxFIxFWC-dkWA")
            XCTAssertThrowsError(try Crypto.shared.deterministicRandomBytes(seed: wrongSeed, length: 64))
        } catch {
            XCTFail("Error during random bytes generation: \(error)")
        }
    }
    
    func testDeriveKey() {
        let sodium = Sodium()
        guard let seed = TestHelper.base64seed.fromBase64, let seedHash = sodium.genericHash.hash(message: seed.bytes) else {
            return XCTFail("Error getting data from base64 seed")
        }
        XCTAssertNoThrow(try Crypto.shared.deriveKey(keyData: seedHash.data, context: "0", index: 1))
        XCTAssertThrowsError(try Crypto.shared.deriveKey(keyData: seedHash.data, context: "asdadasdsada0", index: 1))
        XCTAssertThrowsError(try Crypto.shared.deriveKey(keyData: seed, context: "0", index: 1))
    }
    
    func testConvertToBase64() {
        let testData = "Test string not encoded".data
        XCTAssertEqual(try Crypto.shared.convertToBase64(from: testData), "VGVzdCBzdHJpbmcgbm90IGVuY29kZWQ")
    }
    
    func testConvertFromBase64() {
        let base64String = "VGVzdCBzdHJpbmcgbm90IGVuY29kZWQ"
        XCTAssertEqual(try Crypto.shared.convertFromBase64(from: base64String), "Test string not encoded".data)
    }
    
    func testConverFromBase64Throws() {
        let base64String = "asoidhjaiodhash"
        XCTAssertThrowsError(try Crypto.shared.convertFromBase64(from: base64String))
    }
    
    func testSign() {
        let textToBeSigned = "Test string".data
        guard let seed = "bOqw6X0TH1Xp5jh9eX2KkoLX6wDsgqbFg5-E-cJhAYw".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        do {
            let keyPair = try Crypto.shared.createSigningKeyPair(seed: seed)
            let signedMessage = try Crypto.shared.sign(message: textToBeSigned, privKey: keyPair.privKey)
            XCTAssertEqual(signedMessage.count, 75)
        } catch {
            XCTFail("Error: \(error)")
        }
    }
    
    func testSignThrowsIfWrongSeed() {
        let textToBeSigned = "Test string".data
        guard let wrongSeed = "basdas-E-cJhAYw".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        XCTAssertThrowsError(try Crypto.shared.sign(message: textToBeSigned, privKey: wrongSeed))
    }
    
    func testSignAndSignatureAndVerifySignature() {
        let sodium = Sodium()
        let textToBeSigned = "Test string".data
        guard let pubKey = "Sv83e1XwETq4-buTc9fU29lHxCoRPlxA8Xr2pxnXQdI".fromBase64, let privKey = "bOqw6X0TH1Xp5jh9eX2KkoLX6wDsgqbFg5-E-cJhAYxK_zd7VfAROrj5u5Nz19Tb2UfEKhE-XEDxevanGddB0g".fromBase64, let wrongSeed = "basdas-E-cJhAYw".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        do {
            let signedMessage = try Crypto.shared.sign(message: textToBeSigned, privKey: privKey)
            let signature = try Crypto.shared.signature(message: signedMessage, privKey: privKey)
            XCTAssertTrue(sodium.sign.verify(message: signedMessage.bytes, publicKey: pubKey.bytes, signature: signature.bytes))
            XCTAssertThrowsError(try Crypto.shared.signature(message: signedMessage, privKey: wrongSeed))
        } catch {
            XCTFail("Error: \(error)")
        }
    }
    
    func testEncryptSymmetric() {
        let plainText = "Test string to be encrypted"
        guard let passwordSeed = "L0y8UIj15Tl2jm2k5cZU8avW45GzOQi4kpHD-PdrAT0".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        XCTAssertEqual(try Crypto.shared.encryptSymmetric(plainText.data, secretKey: passwordSeed).count, 67)
    }
    
    func testEncryptSymmetricThrowsIfWrongKey() {
        let plainText = "Test string to be encrypted"
        XCTAssertThrowsError(try Crypto.shared.encryptSymmetric(plainText.data, secretKey: "passwordSeed".data))
    }
    
    func testDecryptSymmetric() {
        let plainText = "Test string to be encrypted"
        guard let cipherText = "OaJdyWCd4eE6YyRzreYhehklMaumW26KZdhfXa3Ro__wexZ-RZ10TPxgdPh4eInwUwYzFBlP7j3hrNiQToxVo8SDFQ".fromBase64 else {
            return XCTFail("Error getting encrypted text")
        }
        guard let passwordSeed = "L0y8UIj15Tl2jm2k5cZU8avW45GzOQi4kpHD-PdrAT0".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        do {
            let decryptedText = try Crypto.shared.decryptSymmetric(cipherText, secretKey: passwordSeed)
            XCTAssertEqual(plainText, String(data: decryptedText, encoding: .utf8))
            XCTAssertThrowsError(try Crypto.shared.decryptSymmetric(cipherText, secretKey: "passwordSeed".data))
        } catch {
            XCTFail("Error decrypting text: \(error)")
        }
    }
    
    func testEncryptAndDecryptSymmetric() {
        let plainText = "Test string to be encrypted"
        guard let passwordSeed = "L0y8UIj15Tl2jm2k5cZU8avW45GzOQi4kpHD-PdrAT0".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        do {
            let cipherText = try Crypto.shared.encryptSymmetric(plainText.data, secretKey: passwordSeed)
            let decryptedText = try Crypto.shared.decryptSymmetric(cipherText, secretKey: passwordSeed)
            XCTAssertEqual(plainText, String(data: decryptedText, encoding: .utf8))
        } catch {
            XCTFail("Error: \(error)")
        }
    }
    
    func testEncryptAssymetricAnonymous() {
        let plainText = "Test string to be encrypted"
        guard let pubKey = "eFw3GjP7Tg1lEWjs8eHwO2DtSX6HC0neDWGF27im0Vs".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        do {
            let cipherText = try Crypto.shared.encrypt(plainText.data, pubKey: pubKey)
            XCTAssertEqual(cipherText.count, 75)
            XCTAssertThrowsError(try Crypto.shared.encrypt(plainText.data, pubKey: "pubKey".data))
        } catch {
            XCTFail("Error: \(error)")
        }
    }
    
    func testEncryptAssymetricAnonymousThrowsIfWrongKey() {
        let plainText = "Test string to be encrypted"
        XCTAssertThrowsError(try Crypto.shared.encrypt(plainText.data, pubKey: "pubKey".data))
    }
    
    func testEncryptAndDecryptAssymetricAnonymous() {
        let sodium = Sodium()
        let plainText = "Test string to be encrypted"
        do {
            let receiverKeyPair = try Crypto.shared.createSessionKeyPair()
            let cipherText = try Crypto.shared.encrypt(plainText.data, pubKey: receiverKeyPair.pubKey)
            guard let decryptedText: Bytes = sodium.box.open(anonymousCipherText: cipherText.bytes, recipientPublicKey: receiverKeyPair.pubKey.bytes, recipientSecretKey: receiverKeyPair.privKey.bytes) else {
                return XCTFail("Error decrypting")
            }
            XCTAssertEqual(plainText, String(data: decryptedText.data, encoding: .utf8))
        } catch {
            XCTFail("Error: \(error)")
        }
    }
    
    func testHashFromData() {
        let plainData = "Test string not hashed".data
        do {
            let hash = try Crypto.shared.hash(plainData)
            XCTAssertEqual(hash, "rBx9Zmgo4NfEjWKq_GS4gF4xRBkEioPaELgNrpuwTPQ".fromBase64)
        } catch {
            XCTFail("Error during hashing: \(error)")
        }
    }
    
    func testHashFromString() {
        let plainText = "Test string not hashed"
        do {
            let hash = try Crypto.shared.hash(plainText)
            XCTAssertEqual(hash, "ac1c7d666828e0d7c48d62aafc64b8805e314419048a83da10b80dae9bb04cf4")
        } catch {
            XCTFail("Error during hashing: \(error)")
        }
    }
    
    func testGenerateSharedKey() {
        guard
            let receiverPublicKey = "Eb-flMo3yBOLTni0mSb9lh74BD5-WuGt35Y8vzerFT4".fromBase64,
            let receiverPrivateKey = "P5RLNPBwAGflCOT87BJz4Z59iSg5gHl_9ky6zbZer6c".fromBase64,
            let senderPublicKey = "i6-KJrCeTCDuVOVQadcJGQzgVXxCahtN2cUxJ5MljjE".fromBase64,
            let senderPrivateKey = "M6hfPulRUwxEipI_xyfKo-naicFfj-ZsXCVOD51z0NU".fromBase64 else {
                return XCTFail("Error getting data from base64 string")
        }
        
        do {
            let receiverSharedKey = try Crypto.shared.generateSharedKey(pubKey: receiverPublicKey, privKey: senderPrivateKey)
            let senderSharedKey = try Crypto.shared.generateSharedKey(pubKey: senderPublicKey, privKey: receiverPrivateKey)
            XCTAssertEqual(receiverSharedKey, senderSharedKey)
        } catch {
            XCTFail("Error during hashing: \(error)")
        }
    }
    
    func testEncryptWithSharedKey() {
        let plainText = "Test string not hashed"
        guard let sharedKey = "msDAsyo_SFR0ixECH5zIM-X0aP87vKktwzeuH2r0A9M".fromBase64 else {
            return XCTFail("Error getting data from base64 string")
        }
        do {
            let cipherText = try Crypto.shared.encrypt(plainText.data, key: sharedKey)
            XCTAssertEqual(cipherText.count, 240)
        } catch {
            XCTFail("Error encrypting: \(error)")
        }
    }
    
    func testEncryptThrowsIfWrongKey() {
        let plainText = "Test string not hashed"
        XCTAssertThrowsError(try Crypto.shared.encrypt(plainText.data, key: "sharedKey".data))
    }
    
    // The ciphertext here was created without padding.
    func testDecryptWithSharedKey() {
        let plainText = "Test string not hashed"
        guard
            let sharedKey = "msDAsyo_SFR0ixECH5zIM-X0aP87vKktwzeuH2r0A9M".fromBase64,
            let cipherText = "KCKwr7w3vppYrNYqwHL6pyPL21bD31k2fVabRrBUhF8rGYbTRPjfpME_Bz3c0Yq0GtWx5d5ZipaKzF1vOiI".fromBase64 else {
                return XCTFail("Error getting data from base64 string")
        }
        do {
            let (decryptedText, _) = try Crypto.shared.decrypt(cipherText, key: sharedKey)
            XCTAssertEqual(plainText, String(data: decryptedText, encoding: .utf8))
            XCTAssertThrowsError(try Crypto.shared.decrypt(cipherText, key: "sharedKey".data))
        } catch {
            XCTFail("Error decrypting: \(error)")
        }
    }
    
    func testSha1() {
        let hash = Crypto.shared.sha1(from: "String")
        XCTAssertEqual(hash, "3df63b7acb0522da685dad5fe84b81fdd7b25264")
    }
}
