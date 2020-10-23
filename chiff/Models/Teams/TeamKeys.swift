//
//  TeamKeys.swift
//  chiff
//
//  Created by Bas Doorn on 23/10/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation
import PromiseKit

/// This is a container for the admin session keys. Used when bootstraping a new team.
struct AdminSessionKeys {
    /// The shared seed for this admin session.
    let seed: Data
    /// The 'browser' keypair for generating the shared seed
    let browserKeyPair: KeyPair
    /// The 'app' keypair for generating the shared seed
    let sharedKeyKeyPair: KeyPair
    /// Used to generate passwords
    let passwordSeed: Data
    /// Used to encrypt messages for this session
    let encryptionKey: Data
    /// Used to sign messages for the server
    let signingKeyPair: KeyPair

    static let cryptoContext = "keynteam"

    var userId: String {
        return browserKeyPair.pubKey.base64.hash
    }

    init() throws {
        self.browserKeyPair = try Crypto.shared.createSessionKeyPair()
        self.sharedKeyKeyPair = try Crypto.shared.createSessionKeyPair()
        self.seed = try Crypto.shared.generateSharedKey(pubKey: browserKeyPair.pubKey, privKey: self.sharedKeyKeyPair.privKey)
        self.passwordSeed = try Crypto.shared.deriveKey(keyData: seed, context: Self.cryptoContext, index: 0)
        self.encryptionKey = try Crypto.shared.deriveKey(keyData: seed, context: Self.cryptoContext, index: 1)
        self.signingKeyPair = try Crypto.shared.createSigningKeyPair(seed: Crypto.shared.deriveKey(keyData: seed, context: Self.cryptoContext, index: 2))
    }

    func encrypt(seed: Data) throws -> String {
        return (try Crypto.shared.encrypt(seed, key: encryptionKey)).base64
    }

    func createAdmin() throws -> TeamUser {
        return TeamUser(pubkey: signingKeyPair.pubKey.base64,
                            userPubkey: sharedKeyKeyPair.pubKey.base64,
                            id: userId,
                            key: seed.base64,
                            created: Date.now,
                            userSyncPubkey: try Seed.publicKey(),
                            isAdmin: true,
                            name: "devices.admin".localized)
    }

}
