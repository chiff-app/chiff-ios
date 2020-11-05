//
//  WebAuthn.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication
import CryptoKit

enum WebAuthnError: Error {
    case wrongRpId
    case notSupported
    case wrongAlgorithm
}

enum WebAuthnAlgorithm: Int, Codable, Equatable {
    case edDSA = -8
    case ECDSA = -7
}

struct WebAuthn: Codable, Equatable {
    let id: String // rpId
    let algorithm: WebAuthnAlgorithm
    let salt: UInt64
    var counter: Int = 0

    static let cryptoContext = "webauthn"

    init(id: String, algorithms: [WebAuthnAlgorithm]) throws {
        var algorithm: WebAuthnAlgorithm?
        if #available(iOS 13.0, *) {
            algorithm = algorithms.first
        } else if algorithms.contains(.edDSA) {
            algorithm = .edDSA
        }
        guard let acceptedAlgorithm = algorithm else {
            throw WebAuthnError.notSupported
        }
        self.algorithm = acceptedAlgorithm
        self.id = id
        var salt: UInt64 = 0
        _ = try withUnsafeMutableBytes(of: &salt, { try Crypto.shared.generateSeed(length: 8).copyBytes(to: $0) })
        self.salt = salt
    }

    func generateKeyPair(accountId: String, context: LAContext?) throws -> KeyPair {
        var value: UInt64 = 0
        _ = withUnsafeMutableBytes(of: &value, { id.sha256Data.copyBytes(to: $0, from: 0..<8) })
        let siteKey = try Crypto.shared.deriveKey(keyData: try Seed.getWebAuthnSeed(context: context), context: Self.cryptoContext, index: value)
        let key = try Crypto.shared.deriveKey(keyData: siteKey, context: String(accountId.sha256Data.base64.prefix(8)), index: salt)
        var keyPair: KeyPair
        switch algorithm {
        case .edDSA: keyPair = try Crypto.shared.createSigningKeyPair(seed: key)
        case .ECDSA:
            if #available(iOS 13.0, *) {
                keyPair = try Crypto.shared.createECDSASigningKeyPair(seed: key)
            } else {
                // Should only occur in the unlikely case that someone downgrades iOS version after initializing.
                throw WebAuthnError.notSupported
            }
        }
        return keyPair
    }

    func pubKey(accountId: String) throws -> String {
        switch algorithm {
        case .edDSA:
            guard let dict = try Keychain.shared.attributes(id: accountId, service: .webauthn) else {
                throw KeychainError.notFound
            }
            guard let pubKey = dict[kSecAttrGeneric as String] as? Data else {
                throw CodingError.unexpectedData
            }
            return try Crypto.shared.convertToBase64(from: pubKey)
        case .ECDSA:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            guard let key: P256.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            return try Crypto.shared.convertToBase64(from: key.publicKey.rawRepresentation)
        }
    }

    func save(accountId: String, keyPair: KeyPair) throws {
        switch algorithm {
        case .edDSA: try Keychain.shared.save(id: accountId, service: .webauthn, secretData: keyPair.privKey, objectData: keyPair.pubKey)
        case .ECDSA:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            let privKey = try P256.Signing.PrivateKey(rawRepresentation: keyPair.privKey)
            try Keychain.shared.saveKey(id: accountId, key: privKey)
        }
    }

    func delete(accountId: String) throws {
        switch algorithm {
        case .edDSA: try Keychain.shared.delete(id: accountId, service: .webauthn)
        case .ECDSA:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            try Keychain.shared.deleteKey(id: accountId)
        }
    }

    mutating func sign(accountId: String, challenge: String, rpId: String) throws -> (String, Int) {
        guard rpId == id else {
            throw WebAuthnError.wrongRpId
        }
        let challengeData = try Crypto.shared.convertFromBase64(from: challenge)
        let data = try createAuthenticatorData() + challengeData
        switch algorithm {
        case .edDSA:
            guard let privKey: Data = try Keychain.shared.get(id: accountId, service: .webauthn) else {
                throw KeychainError.notFound
            }
            let signature = try Crypto.shared.signature(message: data, privKey: privKey)
            return (signature.base64, counter)
        case .ECDSA:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            guard let privKey: P256.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            let signature = try privKey.signature(for: data)
            return (signature.derRepresentation.base64, counter)
        }
    }

    // MARK: - Private functions

    private mutating func createAuthenticatorData() throws -> Data {
        counter += 1
        var data = Data()
        data.append(id.sha256Data)
        data.append(0x05) // UP + UV flags
        data.append(UInt8((counter >> 24) & 0xff))
        data.append(UInt8((counter >> 16) & 0xff))
        data.append(UInt8((counter >> 8) & 0xff))
        data.append(UInt8((counter >> 0) & 0xff))
        return data
    }

}
