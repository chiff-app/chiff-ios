//
//  TeamKeys.swift
//  chiff
//
//  Created by Bas Doorn on 23/10/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation
import PromiseKit

class TeamSessionSeeds {
    /// The shared seed for this admin session.
    let seed: Data
    /// Used to generate passwords
    let passwordSeed: Data
    /// Used to encrypt messages for this session
    let encryptionKey: Data
    /// Used to sign messages for the server
    let signingKeyPair: KeyPair

    static let cryptoContext = "keynteam"

    init(seed: Data) throws {
        self.seed = seed
        self.passwordSeed =  try Crypto.shared.deriveKey(keyData: seed, context: Self.cryptoContext, index: 0) // Used to generate passwords
        self.encryptionKey = try Crypto.shared.deriveKey(keyData: seed, context: Self.cryptoContext, index: 1) // Used to encrypt messages for this session
        self.signingKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.deriveKey(keyData: seed, context: Self.cryptoContext, index: 2)) // Used to sign messages for the server
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

}

/// This is a container for the admin session keys. Used when bootstraping a new team.
class TeamSessionKeys: TeamSessionSeeds {
    /// The 'browser' keypair pubkey for generating the shared seed
    let browserPubKey: Data
    /// The 'app' keypair for generating the shared seed
    let sharedKeyKeyPair: KeyPair

    var sessionId: String {
        return browserPubKey.base64.hash!
    }

    var pubKey: String {
        return sharedKeyKeyPair.pubKey.base64
    }

    private init(browserPubKey: Data) throws {
        self.browserPubKey = browserPubKey
        self.sharedKeyKeyPair = try Crypto.shared.createSessionKeyPair()
        let seed = try Crypto.shared.generateSharedKey(pubKey: self.browserPubKey, privKey: sharedKeyKeyPair.privKey)
        try super.init(seed: seed)
    }

    convenience init(browserPubKey: String) throws {
        try self.init(browserPubKey: Crypto.shared.convertFromBase64(from: browserPubKey))
    }

    convenience init() throws {
        let browserKeyPair = try Crypto.shared.createSessionKeyPair()
        try self.init(browserPubKey: browserKeyPair.pubKey)
    }

    func encrypt(seed: Data) throws -> String {
        return (try Crypto.shared.encrypt(seed, key: encryptionKey)).base64
    }

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

    func save(id: String, data: Data?) throws {
        try super.save(id: id, privKey: sharedKeyKeyPair.privKey, data: data)
    }

}
