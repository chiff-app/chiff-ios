//
//  SSHAccount.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication
import CryptoKit
import PromiseKit

enum SSHError: Error {
    case notSupported
}


public enum SSHAlgorithm: String, Codable, Equatable {
    case edDSA = "ssh-ed25519"
    case ECDSA256 = "ecdsa-sha2-nistp256"

    public var title: String {
        switch self {
        case .edDSA:
            return "Ed25519"
        case .ECDSA256:
            return "ECDSA"
        }
    }

    public var keyLength: Int {
        switch self {
        case .edDSA, .ECDSA256: return 32
        }
    }

    var data: Data {
        return self.rawValue.data(using: .utf8)!
    }

    var curve: Data? {
        switch self {
        case .ECDSA256:
            return "nistp256".data(using: .utf8)!
        default:
            return nil
        }
    }

}

/// An SSH identity.
public struct SSHIdentity: Equatable, Codable, Identity {
    public let id: String // SSH fingerprint, hex encoded
    public var name: String
    public var timesUsed: Int
    public var lastTimeUsed: Date?
    public var lastChange: Timestamp
    public let algorithm: SSHAlgorithm
    let pubKey: String
    let salt: Data

    public var publicKey: String {
        var fingerprintData = SSHIdentity.lengthAndData(of: algorithm.data)
        if let curve = algorithm.curve {
            fingerprintData += SSHIdentity.lengthAndData(of: curve)
        }
        fingerprintData += SSHIdentity.lengthAndData(of: pubKey.fromBase64!)
        return "\(algorithm.rawValue) \(fingerprintData.base64EncodedString()) \(name)"
    }

    static let cryptoContext = "chiffssh"

    /// Create a new SSH identity.
    /// - Parameters:
    ///   - algorithms: The algorithms should be provided in order of preference.
    /// - Throws: Crypto errors if no accepted algorithm is found.
    init(algorithm: SSHAlgorithm, name: String, context: LAContext?) throws {
        if algorithm == .ECDSA256 {
            guard #available(iOS 13.0, *) else {
                throw SSHError.notSupported
            }
        }
        self.algorithm = algorithm
        self.name = name
        self.salt = try Crypto.shared.generateSeed(length: 8)
        var keyPair: KeyPair
        if case .edDSA = algorithm {
            let key = try Crypto.shared.deriveKey(keyData: try Seed.getSSHSeed(context: context), context: Self.cryptoContext, index: self.salt)
            keyPair = try Crypto.shared.createSigningKeyPair(seed: key)
        } else if #available(iOS 13.0, *) {
            let privKey = try Crypto.shared.createSecureEnclaveECDSASigningKeyPair(context: context)
            keyPair = KeyPair(pubKey: privKey.publicKey.x963Representation, privKey: privKey.dataRepresentation)
        } else {
            // Should only occur in the unlikely case that someone downgrades iOS version after initializing.
            throw SSHError.notSupported
        }
        self.pubKey = keyPair.pubKey.base64
        self.timesUsed = 0
        self.lastChange = Date.now
        self.id = SSHIdentity.generateFingerprint(pubkey: keyPair.pubKey, algorithm: algorithm)
        let data = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: self.id, service: .sshIdentity, secretData: keyPair.privKey, objectData: data)
        for session in try BrowserSession.all().filter({ $0.browser == .cli }) {
            _ = try session.updateSSHIdentity(identity: SSHSessionIdentity(identity: self))
        }
    }

    // Documentation in protocol
    public func delete() -> Promise<Void> {
        do {
            try Keychain.shared.delete(id: self.id, service: .sshIdentity)
            for session in try BrowserSession.all().filter({ $0.browser == .cli }) {
                _ = session.deleteAccount(accountId: self.id)
            }
            if algorithm == .ECDSA256 {
                return .value(())
            } else {
                return deleteBackup()
            }
        } catch {
            return Promise(error: error)
        }
    }

    /// Sign a WebAuthn challenge.
    /// - Parameters:
    ///   - challenge: The challenge to be signed.
    /// - Throws: Keychain, Crypto or WebAuthn errors.
    /// - Returns: The signature
    mutating func sign(challenge: String) throws -> String {
        let data = try Crypto.shared.convertFromBase64(from: challenge)
        guard let privKey: Data = try Keychain.shared.get(id: self.id, service: .sshIdentity) else {
            throw KeychainError.notFound
        }
        self.lastTimeUsed = Date()
        self.timesUsed += 1
        switch algorithm {
        case .edDSA:
            let signature = try Crypto.shared.signature(message: data, privKey: privKey)
            return signature.base64
        case .ECDSA256:
            guard #available(iOS 13.0, *) else {
                throw WebAuthnError.notSupported
            }
            let enclaveKey: SecureEnclave.P256.Signing.PrivateKey = try SecureEnclave.P256.Signing.PrivateKey(dataRepresentation: privKey)
            let signature = try enclaveKey.signature(for: data)
            // TODO, perhaps already encode here with length and data for r / s
            return signature.rawRepresentation.base64
        }
    }

    /// Save this object to the keychain.
    /// - Throws: Keychain errors
    func save() throws {
        let data = try PropertyListEncoder().encode(self)
        try Keychain.shared.update(id: self.id, service: .sshIdentity, secretData: nil, objectData: data)
    }


    /// Update the key's name in Keychain and sessions
    /// - Parameter newName: The new name.
    /// - Throws: Keychain errors.
    public mutating func updateName(to newName: String) throws {
        self.name = newName
        self.lastChange = Date.now
        try save()
        for session in try BrowserSession.all().filter({ $0.browser == .cli }) {
            _ = try session.updateSSHIdentity(identity: SSHSessionIdentity(identity: self))
        }
        backup().catchLog("Error updating SSH key backup")
    }

    // MARK: - Static methods

    /// Delete all accounts and related to from the Keychain and identity store.
    public static func deleteAll() {
        Keychain.shared.deleteAll(service: .sshIdentity)
    }

    // MARK: - Private methods

    private static func generateFingerprint(pubkey: Data, algorithm: SSHAlgorithm) -> String {
        var fingerprintData = lengthAndData(of: algorithm.data)
        if let curve = algorithm.curve {
            fingerprintData += lengthAndData(of: curve)
        }
        fingerprintData += lengthAndData(of: pubkey)
        return fingerprintData.sha256.hexEncodedString()
    }

    private static func lengthAndData(of data: Data) -> Data {
        let rawLength = UInt32(data.count)
        var endian = rawLength.bigEndian
        return Data(bytes: &endian, count: 4) + data
    }

}
