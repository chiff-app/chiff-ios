//
//  TeamKeys.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import PromiseKit

protocol TeamSessionSeedsProtocol {
    /// The shared seed for this admin session.
    var seed: Data { get }
    /// Used to generate passwords
    var passwordSeed: Data { get }
    /// Used to encrypt messages for this session
    var encryptionKey: Data { get }
    /// Used to sign messages for the server
    var signingKeyPair: KeyPair { get }

    static var cryptoContext: String { get }
}

extension TeamSessionSeedsProtocol {

    static var cryptoContext: String {
        return "keynteam"
    }

    /// Updates team session seeds in the Keychain.
    /// - Parameters:
    ///     - id: The session ID
    ///     - data: Optionally, the session data to update.
    /// - Throws: KeychainError if updating the Keychain fails for some reason.
    func update(id: String, data: Data?) throws {
        try Keychain.shared.update(id: SessionIdentifier.sharedKey.identifier(for: id), service: TeamSession.encryptionService, secretData: encryptionKey, objectData: data)
        try Keychain.shared.update(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: TeamSession.signingService, secretData: signingKeyPair.privKey)
        try Keychain.shared.update(id: SessionIdentifier.passwordSeed.identifier(for: id), service: TeamSession.signingService, secretData: passwordSeed)
        try Keychain.shared.update(id: SessionIdentifier.sharedSeed.identifier(for: id), service: TeamSession.signingService, secretData: seed)
    }

    /// Save team session seeds in the Keychain.
    /// - Parameters:
    ///   - id: The session ID
    ///   - privKey: The private key of the shared keypair. This never updated and used to update keys in case of admin revocation.
    ///   - data: Optionally, the session data
    /// - Throws: KeychainError if updating the Keychain fails for some reason.
    func save(id: String, privKey: Data, data: Data?) throws {
        try Keychain.shared.save(id: SessionIdentifier.sharedKey.identifier(for: id), service: TeamSession.encryptionService, secretData: encryptionKey, objectData: data)
        try Keychain.shared.save(id: SessionIdentifier.signingKeyPair.identifier(for: id), service: TeamSession.signingService, secretData: signingKeyPair.privKey)
        try Keychain.shared.save(id: SessionIdentifier.passwordSeed.identifier(for: id), service: TeamSession.signingService, secretData: passwordSeed)
        try Keychain.shared.save(id: SessionIdentifier.sharedSeed.identifier(for: id), service: TeamSession.signingService, secretData: seed)
        try Keychain.shared.save(id: SessionIdentifier.sharedKeyPrivKey.identifier(for: id), service: TeamSession.signingService, secretData: privKey)
    }

    // MARK: - Private functions

    fileprivate static func deriveKeys(seed: Data) throws -> (Data, Data, KeyPair) {
        let passwordSeed =  try Crypto.shared.deriveKey(keyData: seed, context: Self.cryptoContext, index: 0) // Used to generate passwords
        let encryptionKey = try Crypto.shared.deriveKey(keyData: seed, context: Self.cryptoContext, index: 1) // Used to encrypt messages for this session
        let signingKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.deriveKey(keyData: seed, context: Self.cryptoContext, index: 2)) // Used to sign messages for the server
        return (passwordSeed, encryptionKey, signingKeyPair)
    }
}

/// A simple container for the different cryptgraphic keys of a `TeamSession`.
struct TeamSessionSeeds: TeamSessionSeedsProtocol {
    let seed: Data
    let passwordSeed: Data
    let encryptionKey: Data
    let signingKeyPair: KeyPair

    init(seed: Data) throws {
        let (passwordSeed, encryptionKey, signingKeyPair) = try Self.deriveKeys(seed: seed)
        self.seed = seed
        self.passwordSeed = passwordSeed
        self.encryptionKey = encryptionKey
        self.signingKeyPair = signingKeyPair
    }
}

/// This is a container for the admin session keys. Used when bootstraping a new team.
struct TeamSessionKeys: TeamSessionSeedsProtocol {
    let seed: Data
    let passwordSeed: Data
    let encryptionKey: Data
    let signingKeyPair: KeyPair
    let browserPubKey: Data
    let sharedKeyKeyPair: KeyPair

    var sessionId: String {
        return browserPubKey.base64.hash!
    }

    var pubKey: String {
        return sharedKeyKeyPair.pubKey.base64
    }

    /// Encrypt the seed with the encryption key.
    /// - Parameter seed: The seed
    /// - Throws: Crypto errors.
    /// - Returns: The base64-encoded encrypted seed.
    func encrypt(seed: Data) throws -> String {
        return (try Crypto.shared.encrypt(seed, key: encryptionKey)).base64
    }

    /// Create an admin `TeamUser` with the public key of the backup seed set
    /// as this user's `userSyncPubkey`.
    /// - Throws: Keychain errors
    /// - Returns: The `TeamUser`.
    func createAdmin() throws -> TeamUser {
        return TeamUser(pubkey: signingKeyPair.pubKey.base64,
                            userPubkey: sharedKeyKeyPair.pubKey.base64,
                            id: sessionId,
                            key: seed.base64,
                            created: Date.now,
                            userSyncPubkey: try Seed.publicKey(),
                            isAdmin: true,
                            name: "devices.admin".localized)
    }

    /// Save to datta to the Keychain, optionally providing attribute data.
    /// - Parameters:
    ///   - id: The id for the Keychain.
    ///   - data: Optionally, attribute data.
    /// - Throws: Keychain errors.
    func save(id: String, data: Data?) throws {
        try save(id: id, privKey: sharedKeyKeyPair.privKey, data: data)
    }

}

extension TeamSessionKeys {

    /// Initialize the `TeamSessionKey` from a `browserPubKey`. Our keypair will be generated.
    /// - Parameter browserPubKey: Their public key.
    /// - Throws: Crypto or Keychain errors.
    init(browserPubKey: Data) throws {
        let sharedKeyKeyPair = try Crypto.shared.createSessionKeyPair()
        let seed = try Crypto.shared.generateSharedKey(pubKey: browserPubKey, privKey: sharedKeyKeyPair.privKey)
        let (passwordSeed, encryptionKey, signingKeyPair) = try Self.deriveKeys(seed: seed)
        self.init(seed: seed, passwordSeed: passwordSeed, encryptionKey: encryptionKey, signingKeyPair: signingKeyPair, browserPubKey: browserPubKey, sharedKeyKeyPair: sharedKeyKeyPair)
    }

    /// Initialize the `TeamSessionKey` from a `browserPubKey`. Our keypair will be generated.
    ///     Convencience initializer that decodes the public key from base64.
    /// - Parameter browserPubKey: Their base64-encoded public key.
    /// - Throws: Crypto or Keychain errors.
    init(browserPubKey: String) throws {
        try self.init(browserPubKey: Crypto.shared.convertFromBase64(from: browserPubKey))
    }

    /// Initialize the `TeamSessionKey`, where both their keypair and our keypair will be generated.
    /// - Throws: Crypto or Keychain errors.
    init() throws {
        let browserKeyPair = try Crypto.shared.createSessionKeyPair()
        try self.init(browserPubKey: browserKeyPair.pubKey)
    }

}
