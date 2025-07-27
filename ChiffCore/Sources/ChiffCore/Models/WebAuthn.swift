//
//  WebAuthn.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication
import CryptoKit
import PromiseKit

enum WebAuthnError: Error {
    case wrongRpId
    case notSupported
    case wrongAlgorithm
}

public enum WebAuthnAlgorithm: Int, Codable, Equatable {
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

public struct WebAuthnExtensions: Codable {
    let credentialProtectionPolicy: UInt8?

    enum CodingKeys: String, CodingKey {
        case credentialProtectionPolicy = "cp"
    }
}

public struct WebAuthnAttestation: Codable {
    let signature: String
    let clientData: Data
    let certificates: [String]?

    internal init(signature: String, clientData: Data, certificates: [String]?) {
        self.signature = signature
        self.clientData = clientData
        self.certificates = certificates
    }

}

/// A WebAuthn for an account.
public struct WebAuthn: Equatable {
    /// This is the RPid (relying party id) in WebAuthn definition.
    public let id: String
    let algorithm: WebAuthnAlgorithm
    let salt: Data
    public let userHandle: String?
    public var authenticatorData: Data {
        var flags: UInt8 = 0x00
        flags |= 1      // UP flag
        flags |= 1 << 2 // UV flag
        flags |= 1 << 3 // BE flag
        flags |= 1 << 4 // BS flag
        return id.sha256Data + Data([flags, 0x00, 0x00, 0x00, 0x00]) // We're not using the counter.
    }

    static let cryptoContext = "webauthn"
    static let AAGUID = Data([UInt8](arrayLiteral: 0x73, 0x07, 0x21, 0x2e, 0xc6, 0xdb, 0x98, 0x5e, 0xcd, 0x80, 0x55, 0xf6, 0x4a, 0x1f, 0x10, 0x07))

    /// Create a new WebAuthn object.
    /// - Parameters:
    ///   - id: The relying party id (RPid)
    ///   - algorithms: The algorithms should be provided in order of preference.
    /// - Throws: Crypto errors if no accepted algorithm is found.
    public init(id: String, algorithms: [WebAuthnAlgorithm], userHandle: String?) throws {
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
        self.userHandle = userHandle
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

    /// Return the public key of the signing keypair.
    /// - Parameter accountId: The account id.
    /// - Throws: Crypto or Keychain errors.
    /// - Returns: The public key.
    func pubKey(accountId: String) throws -> Data {
        switch algorithm {
        case .edDSA:
            guard let pubKey = try Keychain.shared.attributes(id: accountId, service: .account(attribute: .webauthn)) else {
                throw KeychainError.notFound
            }
            return pubKey
        case .ECDSA256:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            guard let key: P256.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            return key.publicKey.rawRepresentation
        case .ECDSA384:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            guard let key: P384.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            return key.publicKey.rawRepresentation
        case .ECDSA512:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            guard let key: P521.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            return key.publicKey.rawRepresentation
        }
    }

    /// Return the base64 encoded public key of the signing keypair.
    /// - Parameter accountId: The account id.
    /// - Throws: Crypto or Keychain errors.
    /// - Returns: The base64 encoded public key.
    func pubKey(accountId: String) throws -> String {
        return try Crypto.shared.convertToBase64(from: pubKey(accountId: accountId))
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
    /// - Returns: The signature
    func sign(accountId: String, challenge: String, rpId: String, extensions: WebAuthnExtensions?) throws -> String {
        guard rpId == id else {
            throw WebAuthnError.wrongRpId
        }
        let challengeData = try Crypto.shared.convertFromBase64(from: challenge)
        return (try self.sign(accountId: accountId, challenge: challengeData, rpId: rpId, extensions: extensions)).base64
    }
    
    /// Sign a WebAuthn challenge.
    /// - Parameters:
    ///   - accountId: The account id.
    ///   - challenge: The challenge to be signed.
    ///   - rpId: The relying party id.
    /// - Throws: Keychain, Crypto or WebAuthn errors.
    /// - Returns: The signature
    public func sign(accountId: String, challenge: Data, rpId: String, extensions: WebAuthnExtensions?) throws -> Data {
        guard rpId == id else {
            throw WebAuthnError.wrongRpId
        }
        let data = try createAuthenticatorData(accountId: nil, extensions: nil) + challenge
        return try sign(accountId: accountId, data: data)
    }
    
    /// Get the attestation, used for iOS Passkey authentication. In the browser it is generated by the extension.
    /// - Parameters:
    ///   - accountId: The account id
    ///   - extensions: Extensions that should be included
    /// - Returns: The attestation object.
    public func getAttestation(accountId: String, extensions: WebAuthnExtensions?) throws -> Data {
        let authData = try createAuthenticatorData(accountId: accountId, extensions: extensions)
        // {"fmt": "none", "attStmt": {}, "authData": <authdatabytes>}
        var data = Data([UInt8](arrayLiteral: 0xa3, 0x63, 0x66, 0x6d, 0x74, 0x64, 0x6e, 0x6f, 0x6e, 0x65, 0x67, 0x61, 0x74, 0x74, 0x53, 0x74, 0x6d, 0x74, 0xa0, 0x68, 0x61, 0x75, 0x74, 0x68, 0x44, 0x61, 0x74, 0x61, 0x58, UInt8(authData.count & 0xff)))
        data.append(authData)
        return data
    }

    /// Get a WebAuthn attestation
    /// - Parameters:
    ///   - accountId: The account id.
    ///   - clientDataHash: The SHA256 hash of the client data.
    ///   - extensions: Extensions that should be included
    /// - Throws: Keychain, Crypto or WebAuthn errors.
    /// - Returns: A triple with the signature, used counter and the attestation certificate.
    func signAttestation(accountId: String, clientDataHash clientDataHashString: String, extensions: WebAuthnExtensions?) -> Promise<WebAuthnAttestation> {
        do {
            let authData = try createAuthenticatorData(accountId: accountId, extensions: extensions)
            let clientDataHash = try Crypto.shared.convertFromBase64(from: clientDataHashString)
            let data = authData + clientDataHash
            if #available(iOS 14.0, *) { // Anonymization CA
                let privKey = try SecureEnclave.P256.Signing.PrivateKey()
                let signature = try privKey.signature(for: data)
                return firstly {
                    Attestation.attestWebAuthnKeypair(keypair: privKey)
                }.map { WebAuthnAttestation(signature: signature.derRepresentation.base64, clientData: clientDataHash, certificates: $0) }
            } else { // Self-signing
                let signature = try sign(accountId: accountId, data: clientDataHash)
                return .value(WebAuthnAttestation(signature: signature.base64, clientData: clientDataHash, certificates: nil))
            }
        } catch {
            return Promise(error: error)
        }

    }


    // MARK: - Private functions

    private func createAuthenticatorData(accountId: String?, extensions: WebAuthnExtensions?) throws -> Data {
        var data = authenticatorData
        if let accountId = accountId {
            try appendAttestation(data: &data, accountId: accountId)
        }
        if let extensions = extensions {
            appendExtensions(data: &data, extensions: extensions)
        }
        return data
    }

    private func appendAttestation(data: inout Data, accountId: String) throws {
        data[32] |= 1 << 6 // Set attestation flag
        let accountIdData = try Crypto.shared.fromHex(accountId)
        data.append(WebAuthn.AAGUID)
        data.append(UInt8((accountIdData.count >> 8) & 0xff))
        data.append(UInt8(accountIdData.count & 0xff))
        data.append(accountIdData)
        switch algorithm {
        case .edDSA:
            data.append(contentsOf: [UInt8](arrayLiteral: 0xa4, 0x01, 0x01, 0x03, 0x27, 0x20, 0x06, 0x21, 0x58, 0x20))
            data.append(try pubKey(accountId: accountId))
        case .ECDSA256:
            let pubkey: Data = try pubKey(accountId: accountId)
            data.append(contentsOf: [UInt8](arrayLiteral: 0xa5, 0x01, 0x02, 0x03, 0x26, 0x20, 0x01, 0x21, 0x58, 0x20))
            data.append(pubkey.prefix(algorithm.keyLength))
            data.append(contentsOf: [0x22, 0x58, 0x20])
            data.append(pubkey.suffix(algorithm.keyLength))
        case .ECDSA384:
            let pubkey: Data = try pubKey(accountId: accountId)
            data.append(contentsOf: [UInt8](arrayLiteral: 0xa5, 0x01, 0x02, 0x03, 0x38, 0x22, 0x20, 0x02, 0x21, 0x58, 0x30))
            data.append(pubkey.prefix(algorithm.keyLength))
            data.append(contentsOf: [UInt8](arrayLiteral: 0x22, 0x58, 0x30))
            data.append(pubkey.suffix(algorithm.keyLength))
        case .ECDSA512:
            let pubkey: Data = try pubKey(accountId: accountId)
            data.append(contentsOf: [UInt8](arrayLiteral: 0xa5, 0x01, 0x02, 0x03, 0x38, 0x23, 0x20, 0x03, 0x21, 0x58, 0x42))
            data.append(pubkey.prefix(algorithm.keyLength + 1)) // We also need the heading zero bytes here
            data.append(contentsOf: [UInt8](arrayLiteral: 0x22, 0x58, 0x42))
            data.append(pubkey.suffix(algorithm.keyLength + 1)) // We also need the heading zero bytes here
        }
    }

    private func appendExtensions(data: inout Data, extensions: WebAuthnExtensions) {
        var count = 0
        var extensionData = Data()
        // Since we should encode CBOR canonical and the key here is 'credProtect' (11 chars) and the next one 'hmac-secret' (12 chars), this one goes first
        if let policy = extensions.credentialProtectionPolicy {
            count += 1
            extensionData.append(contentsOf: [UInt8](arrayLiteral: 0x6b, 0x63, 0x72, 0x65, 0x64, 0x50, 0x72, 0x6F, 0x74, 0x65, 0x63, 0x74, policy))
        }
        if !extensionData.isEmpty {
            data[32] |= 1 << 7 // Set extension flag
            data.append(UInt8(0xa0 + count))
            data.append(extensionData)
        }
    }
    
    @available(iOS 26.0, *)
    func getPrivKey(accountId: String) throws -> Data {
        switch algorithm {
        case .edDSA:
            guard let privKey: Data = try Keychain.shared.get(id: accountId, service: .account(attribute: .webauthn)) else {
                throw KeychainError.notFound
            }
            return privKey
        case .ECDSA256:
            guard let privKey: P256.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            return privKey.derRepresentation
        case .ECDSA384:
            guard let privKey: P384.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            return privKey.derRepresentation
        case .ECDSA512:
            guard let privKey: P521.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            return privKey.derRepresentation
        }
    }

    private func sign(accountId: String, data: Data) throws -> Data {
        switch algorithm {
        case .edDSA:
            guard let privKey: Data = try Keychain.shared.get(id: accountId, service: .account(attribute: .webauthn)) else {
                throw KeychainError.notFound
            }
            let signature = try Crypto.shared.signature(message: data, privKey: privKey)
            return signature
        case .ECDSA256:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            guard let privKey: P256.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            let signature = try privKey.signature(for: data)
            return signature.derRepresentation
        case .ECDSA384:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            guard let privKey: P384.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            let signature = try privKey.signature(for: data)
            return signature.derRepresentation
        case .ECDSA512:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            guard let privKey: P521.Signing.PrivateKey = try Keychain.shared.getKey(id: accountId, context: nil) else {
                throw KeychainError.notFound
            }
            let signature = try privKey.signature(for: data)
            return signature.derRepresentation
        }
    }

}

extension WebAuthn: Codable {

    enum CodingKeys: CodingKey {
        case id
        case algorithm
        case salt
        case userHandle
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.algorithm = try values.decode(WebAuthnAlgorithm.self, forKey: .algorithm)
        do {
            self.salt = try values.decode(Data.self, forKey: .salt)
        } catch is DecodingError {
            var integer = try values.decode(UInt64.self, forKey: .salt)
            self.salt = withUnsafeBytes(of: &integer) { Data($0) }
        }
        self.userHandle = try values.decodeIfPresent(String.self, forKey: .userHandle)
    }
}
