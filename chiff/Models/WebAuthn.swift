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
    case ECDSA256 = -7
    case ECDSA384 = -35
    case ECDSA512 = -36

    var keyLength: Int {
        switch self {
        case .edDSA, .ECDSA256: return 32
        case .ECDSA384: return 48
        case .ECDSA512: return 65
        }
    }
}

/// A WebAuthn for an account.
struct WebAuthn: Equatable {
    /// This is the RPid (relying party id) in WebAuthn definition.
    let id: String
    let algorithm: WebAuthnAlgorithm
    let salt: Data
    var counter: Int = 0

    static let cryptoContext = "webauthn"

    /// Create a new WebAuthn object.
    /// - Parameters:
    ///   - id: The relying party id (RPid)
    ///   - algorithms: The algorithms should be provided in order of preference.
    /// - Throws: Crypto errors if no accepted algorithm is found.
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
        self.salt = try Crypto.shared.generateSeed(length: 8)
    }

    /// Generate a WebAuthn signing keypair.
    /// - Parameters:
    ///   - accountId: The account id.
    ///   - context: Optionally, an authenticated `LAContext` object.
    /// - Throws: Crypto or Keychain errors.
    /// - Returns: The signing keypair.
    func generateKeyPair(accountId: String, context: LAContext?) throws -> KeyPair {
        let siteKey = try Crypto.shared.deriveKey(keyData: try Seed.getWebAuthnSeed(context: context), context: Self.cryptoContext, index: id.sha256Data)
        let key = try Crypto.shared.deriveKey(keyData: siteKey, context: String(accountId.sha256Data.base64.prefix(8)), index: salt)
        var keyPair: KeyPair
        if case .edDSA = algorithm {
            keyPair = try Crypto.shared.createSigningKeyPair(seed: key)
        } else if #available(iOS 13.0, *) {
            keyPair = try Crypto.shared.createECDSASigningKeyPair(seed: key, algorithm: algorithm)
        } else {
            // Should only occur in the unlikely case that someone downgrades iOS version after initializing.
            throw WebAuthnError.notSupported
        }
        return keyPair
    }

    /// Return the base64 encoded public key of the signing keypair.
    /// - Parameter accountId: The account id.
    /// - Throws: Crypto or Keychain errors.
    /// - Returns: The base64 encoded public key.
    func pubKey(accountId: String) throws -> String {
        switch algorithm {
        case .edDSA:
            guard let pubKey = try Keychain.shared.attributes(id: accountId, service: .account(attribute: .webauthn)) else {
                throw KeychainError.notFound
            }
            return try Crypto.shared.convertToBase64(from: pubKey)
        case .ECDSA256:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            guard let key: P256.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            return try Crypto.shared.convertToBase64(from: key.publicKey.rawRepresentation)
        case .ECDSA384:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            guard let key: P384.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            return try Crypto.shared.convertToBase64(from: key.publicKey.rawRepresentation)
        case .ECDSA512:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            guard let key: P521.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            return try Crypto.shared.convertToBase64(from: key.publicKey.rawRepresentation)
        }
    }

    /// Save the keypair to the Keychain.
    /// - Parameters:
    ///   - accountId: The account id to use as an identifier.
    ///   - keyPair: The keypair.
    /// - Throws: Crypto or Keychain errors.    
    func save(accountId: String, keyPair: KeyPair) throws {
        switch algorithm {
        case .edDSA: try Keychain.shared.save(id: accountId, service: .account(attribute: .webauthn), secretData: keyPair.privKey, objectData: keyPair.pubKey)
        case .ECDSA256:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            let privKey = try P256.Signing.PrivateKey(rawRepresentation: keyPair.privKey)
            try Keychain.shared.saveKey(id: accountId, key: privKey)
        case .ECDSA384:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            let privKey = try P384.Signing.PrivateKey(rawRepresentation: keyPair.privKey)
            try Keychain.shared.saveKey(id: accountId, key: privKey)
        case .ECDSA512:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            let privKey = try P521.Signing.PrivateKey(rawRepresentation: keyPair.privKey)
            try Keychain.shared.saveKey(id: accountId, key: privKey)
        }
    }

    /// Delete this WebAuthn keypair from the Keychain.
    /// - Parameter accountId: The account id.
    /// - Throws: Keyhain errors.
    func delete(accountId: String) throws {
        switch algorithm {
        case .edDSA: try Keychain.shared.delete(id: accountId, service: .account(attribute: .webauthn))
        default:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            try Keychain.shared.deleteKey(id: accountId)
        }
    }

    /// Sign a WebAuthn challenge.
    /// - Parameters:
    ///   - accountId: The account id.
    ///   - challenge: The challenge to be signed.
    ///   - rpId: The relying party id.
    /// - Throws: Keychain, Crypto or WebAuthn errors.
    /// - Returns: A tuple with the signature and the used counter.
    mutating func sign(accountId: String, challenge: String, rpId: String) throws -> (String, Int) {
        guard rpId == id else {
            throw WebAuthnError.wrongRpId
        }
        let challengeData = try Crypto.shared.convertFromBase64(from: challenge)
        let data = try createAuthenticatorData() + challengeData
        switch algorithm {
        case .edDSA:
            guard let privKey: Data = try Keychain.shared.get(id: accountId, service: .account(attribute: .webauthn)) else {
                throw KeychainError.notFound
            }
            let signature = try Crypto.shared.signature(message: data, privKey: privKey)
            return (signature.base64, counter)
        case .ECDSA256:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            guard let privKey: P256.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            let signature = try privKey.signature(for: data)
            return (signature.derRepresentation.base64, counter)
        case .ECDSA384:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            guard let privKey: P384.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            let signature = try privKey.signature(for: data)
            return (signature.derRepresentation.base64, counter)
        case .ECDSA512:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            guard let privKey: P521.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
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

extension WebAuthn: Codable {

    enum CodingKeys: CodingKey {
        case id
        case algorithm
        case salt
        case counter
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.algorithm = try values.decode(WebAuthnAlgorithm.self, forKey: .algorithm)
        do {
            self.salt = try values.decode(Data.self, forKey: .salt)
        } catch is DecodingError {
            var integer = try values.decode(UInt64.self, forKey: .salt)
            self.salt = withUnsafeBytes(of: &integer) { Data($0) }
        }
        self.counter = try values.decode(Int.self, forKey: .counter)
    }
}
