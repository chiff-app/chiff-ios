//
//  CryptoTests.swift
//  ChiffCoreTests
//
//  Copyright: see LICENSE.md
//

import XCTest
import Sodium
import CryptoKit

@testable import ChiffCore

class CryptoTests: XCTestCase {

    func testGenerateSeedDoesntThrow() {
        XCTAssertNoThrow(try Crypto.shared.generateSeed())
    }

    func testGenerateRandomIdDoesntThrow() {
        XCTAssertNoThrow(try Crypto.shared.generateRandomId())
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
        guard let seed = TestHelper.base64seed.fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        XCTAssertNoThrow(try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .backupSeed, context: TestHelper.CRYPTO_CONTEXT))
        XCTAssertThrowsError(try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: "200000000000"))
    }
    
    func testDeriveKeyFromSeed() {
        guard let seed = TestHelper.base64seed.fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        XCTAssertEqual(try Crypto.shared.deriveKeyFromSeed(seed: seed, keyType: .passwordSeed, context: TestHelper.CRYPTO_CONTEXT).base64, TestHelper.passwordSeed)
    }
    
    func testCreateSessionKeyPairDoesntThrow() {
        XCTAssertNoThrow(try Crypto.shared.createSessionKeyPair())
    }
    
    func testCreateSigningKeyPairDoesntThrow() {
        guard let seed = TestHelper.backupSeed.fromBase64 else {
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
        guard let seed = TestHelper.backupSeed.fromBase64, let pubKey = TestHelper.backupPubKey.fromBase64, let privKey = TestHelper.backupPrivKey.fromBase64 else {
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
        guard let seed = TestHelper.passwordSeed.fromBase64, let wrongSeed = "lasjndkjsnk".fromBase64 else {
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
        guard let seed = TestHelper.passwordSeed.fromBase64, let wrongSeed = "lasjndkjsnk".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        XCTAssertNoThrow(try Crypto.shared.deriveKey(keyData: seed, context: TestHelper.CRYPTO_CONTEXT, index: 1))
        XCTAssertEqual(try Crypto.shared.deriveKey(keyData: seed, context: TestHelper.CRYPTO_CONTEXT, index: 1).base64, "fk1VVbjJuj6klZBWrDieD_9J_4brbaoeaIJJavWBtnM")
        XCTAssertThrowsError(try Crypto.shared.deriveKey(keyData: seed, context: "asdadasdsada0", index: 1))
        XCTAssertThrowsError(try Crypto.shared.deriveKey(keyData: wrongSeed, context: TestHelper.CRYPTO_CONTEXT, index: 1))
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

    func testConvertFromHex() {
        let hexString = "5465737420737472696e67206e6f7420656e636f646564"
        XCTAssertEqual(try Crypto.shared.fromHex(hexString), "Test string not encoded".data)
    }
    
    func testSign() {
        let textToBeSigned = "Test string".data
        guard let seed = TestHelper.backupSeed.fromBase64 else {
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
        guard let pubKey = TestHelper.backupPubKey.fromBase64, let privKey = TestHelper.backupPrivKey.fromBase64, let wrongSeed = "basdas-E-cJhAYw".fromBase64 else {
            return XCTFail("Error getting data from base64 seed")
        }
        do {
            let signedMessage = try Crypto.shared.sign(message: textToBeSigned, privKey: privKey)
            let signature = try Crypto.shared.signature(message: signedMessage, privKey: privKey)
            print(signature.base64)
            XCTAssertTrue(sodium.sign.verify(message: signedMessage.bytes, publicKey: pubKey.bytes, signature: signature.bytes))
            XCTAssertThrowsError(try Crypto.shared.signature(message: signedMessage, privKey: wrongSeed))
        } catch {
            XCTFail("Error: \(error)")
        }
    }
    
    func testEncryptSymmetric() {
        let plainText = "Test string to be encrypted"
        guard let passwordSeed = TestHelper.passwordSeed.fromBase64 else {
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
        guard let passwordSeed = TestHelper.passwordSeed.fromBase64 else {
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
        guard let passwordSeed = TestHelper.passwordSeed.fromBase64 else {
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
        let plainText = "Test string not encrypted"
        guard let sharedKey = TestHelper.sharedKey.fromBase64 else {
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
        let plainText = "Test string not encrypted"
        guard
            let sharedKey = TestHelper.sharedKey.fromBase64,
            let cipherText = "4fLDZ4hn6uZeV5jNJZSXNLswYeXiwnkUkXx-DQs-quZZUX3_BM7osdtdfZBcrvquZPzMaHb4RvzLwiLNeR7NBog".fromBase64 else {
                return XCTFail("Error getting data from base64 string")
        }
        do {
            let decryptedText = try Crypto.shared.decrypt(cipherText, key: sharedKey, version: 0)
            XCTAssertEqual(plainText, String(data: decryptedText, encoding: .utf8))
            XCTAssertThrowsError(try Crypto.shared.decrypt(cipherText, key: "sharedKey".data, version: 0))
        } catch {
            XCTFail("Error decrypting: \(error)")
        }
    }

    // The ciphertext here was created with padding.
    func testDecryptWithSharedKeyWithPadding() {
        let plainText = "Test string not encrypted"
        guard
            let sharedKey = TestHelper.sharedKey.fromBase64,
            let cipherText = "kQ58zt5qqPeVpx6rqo3g9BuLMJIbrCx-UNLFlhTdUCM1Or_secFlH49OvDt-_PZ54XWU4Sd02olDurn1cHkBQClA3K4GHpnL865guKxHSE2vVfs31Ezs4hHnBWkUokFAfot-WCKKSiIi4NSRK1YCKOM2x65dUqRAsf1rb-9hrG7Sn-7vRhrpX6gq-RFzXckq0yNKKM5iTY-Q0E9EljgPljSvBVO65lEOjaSyFfX29YqbD5PHeugPwGphreGrt0HSZ15801HJeG5m4xKXUaN2xVKJfZHCszUL7Xw-DQXcXTAvBPlD9vo91RJ5xLXmSW9-".fromBase64 else {
                return XCTFail("Error getting data from base64 string")
        }
        do {
            let decryptedText = try Crypto.shared.decrypt(cipherText, key: sharedKey, version: 1)
            XCTAssertEqual(plainText, String(data: decryptedText, encoding: .utf8))
        } catch {
            XCTFail("Error decrypting: \(error)")
        }
    }

    func testDecryptWithSharedKeyThrowsWithSmallCiphertext() {
        guard
            let sharedKey = TestHelper.sharedKey.fromBase64,
            let cipherText = "qVUK".fromBase64 else {
                return XCTFail("Error getting data from base64 string")
        }
         XCTAssertThrowsError(try Crypto.shared.decrypt(cipherText, key: sharedKey, version: 0))
    }
    
    func testSha256String() {
        let hash = Crypto.shared.sha256(from: "String")
        XCTAssertEqual(hash, "b2ef230e7f4f315a28cdcc863028da31f7110f3209feb76e76fed0f37b3d8580")
    }
    
    func testSha256Data() {
        let hash = Crypto.shared.sha256(from: "String".data)
        XCTAssertEqual(hash, "su8jDn9PMVoozcyGMCjaMfcRDzIJ_rdudv7Q83s9hYA".fromBase64)
    }

    func testEquals() {
        let hexString = "5465737420737472696e67206e6f7420656e636f646564"
        let base64String = "VGVzdCBzdHJpbmcgbm90IGVuY29kZWQ"
        XCTAssertTrue(Crypto.shared.equals(first: try Crypto.shared.convertFromBase64(from: base64String), second: try Crypto.shared.fromHex(hexString)))
    }

    @available(iOS 14.0, *)
    func testECDSA256KeyPair() {
        do {
            guard let seed = "9UOiqnsOWeOi2BQxp3upjjWEBbs-s015PCaWthwxSQM".fromBase64 else {
                throw CryptoError.base64Decoding
            }
            let keypair = try Crypto.shared.createECDSASigningKeyPair(seed: seed, algorithm: .ECDSA256)
            XCTAssertEqual("5ilW_l14-8ItmcAbNE3jVQCtBPFcVSq3Vi8T4-97C2gk2CGID_KJ_wRryGFL-NvoAYL4opY0pVy8kowZXwKUuA", keypair.pubKey.base64)
            let privKey = try P256.Signing.PrivateKey(rawRepresentation: keypair.privKey)
            let sig = try privKey.signature(for: "test".data(using: .utf8)!)
            print(privKey.publicKey.derRepresentation.hexEncodedString())
            print(sig.derRepresentation.hexEncodedString())
        } catch {
            XCTFail("Error creating keypair: \(error)")
        }

    }

    @available(iOS 13.0, *)
    func testECDSA384KeyPair() {
        do {
            guard let seed = "9UOiqnsOWeOi2BQxp3upjjWEBbs-s015PCaWthwxSQM".fromBase64 else {
                throw CryptoError.base64Decoding
            }
            let keypair = try Crypto.shared.createECDSASigningKeyPair(seed: seed, algorithm: .ECDSA384)
            XCTAssertEqual("4od8MJRgZsYpNhnb7ZoOBXUFoGKrl7J_WtkOppuJzfck9L3nD7mgJ6PsJmHoxyLr9oEi8RLQcyiVGk3ihN8x6xeTQA4n8WMmoAl28hwTIS2kVWiqLO_5QpMbfnzRysQe", keypair.pubKey.base64)
        } catch {
            XCTFail("Error creating keypair: \(error)")
        }

    }

    @available(iOS 13.0, *)
    func testECDSA512KeyPair() {
        do {
            guard let seed = "9UOiqnsOWeOi2BQxp3upjjWEBbs-s015PCaWthwxSQM".fromBase64 else {
                throw CryptoError.base64Decoding
            }
            let keypair = try Crypto.shared.createECDSASigningKeyPair(seed: seed, algorithm: .ECDSA512)
            XCTAssertEqual("Aey5qFDh7qpwpXcUymujRDcIyqEfG5utEzIAsyEVNxof01zY0myiV8EU25yi-rE4i9nBfA5MX67xq9qDxMZj4Hy0ACdPfI4Keo8KS4D0avEEX3jeQ6Iub-0XRo4H2YcavwiaYz0tMb1WjGmiybs1JYCaxo0gba3dA1Pe4xjAtXn6h0hd", keypair.pubKey.base64)
        } catch {
            XCTFail("Error creating keypair: \(error)")
        }
    }



}
