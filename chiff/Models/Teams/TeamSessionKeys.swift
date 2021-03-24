//
//  TeamKeys.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import PromiseKit
import ChiffCore

extension TeamSessionKeys {
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

}
