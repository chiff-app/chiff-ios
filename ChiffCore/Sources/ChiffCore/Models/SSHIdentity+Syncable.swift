//
//  SSHIdentity+Syncable.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication
import CryptoKit
import PromiseKit

extension SSHIdentity: Syncable {

    public typealias BackupType = BackupSSHIdentity

    public static var syncEndpoint: SyncEndpoint {
        return .sshkeys
    }

    public var sync: Bool {
        return algorithm != .ECDSA256
    }

    /// Get all Ed25519 SSH identities from the Keychain.
    /// - Parameter context: Optionally, an LAContext
    /// - Throws: Keychain or decoding errors.
    /// - Returns: A dictionary with SSH identities.
    public static func all(context: LAContext?) throws -> [String: SSHIdentity] {
        guard let dataArray = try Keychain.shared.all(service: .sshIdentity, context: context, label: nil) else {
            return [:]
        }
        let decoder = PropertyListDecoder()

        return Dictionary(uniqueKeysWithValues: try dataArray.map { (dict) in
            guard let data = dict[kSecAttrGeneric as String] as? Data else {
                throw CodingError.unexpectedData
            }
            let identity = try decoder.decode(SSHIdentity.self, from: data)
            return (identity.id, identity)
        })
    }

    // Documentation in protocol
    public static func get(id: String, context: LAContext?) throws -> SSHIdentity? {
        guard let data = try Keychain.shared.attributes(id: id, service: .sshIdentity, context: context) else {
            return nil
        }

        let decoder = PropertyListDecoder()
        return try decoder.decode(SSHIdentity.self, from: data)
    }


    // Documentation in protocol.
    public static func create(backupObject: BackupSSHIdentity, context: LAContext?) throws {
        _ = try SSHIdentity(backupObject: backupObject, context: context)
    }

    // Documentation in protocol.
    public static func notifyObservers() {
        NotificationCenter.default.postMain(name: .accountsLoaded, object: nil)
    }

    // MARK: - Init

    /// Intialize a `SSHIdentity` from backup data.
    /// - Parameters:
    ///   - backupObject: The backup data object.
    ///   - context: Optionally, an authenticated `LAContext` object.
    /// - Throws: Keychain, decoding or password generating errors.
    init(backupObject: BackupSSHIdentity, context: LAContext?) throws {
        guard backupObject.algorithm != .ECDSA256 else {
            throw SSHError.notSupported
        }
        self.algorithm = backupObject.algorithm
        self.name = backupObject.name
        self.salt = backupObject.salt.fromBase64!
        let key = try Crypto.shared.deriveKey(keyData: try Seed.getSSHSeed(context: context), context: Self.cryptoContext, index: self.salt)
        let keyPair = try Crypto.shared.createSigningKeyPair(seed: key)
        self.pubKey = keyPair.pubKey.base64
        self.timesUsed = 0
        self.id = backupObject.id
        self.lastChange = backupObject.lastChange
        let data = try PropertyListEncoder().encode(self)
        try Keychain.shared.save(id: self.id, service: .sshIdentity, secretData: keyPair.privKey, objectData: data)
    }


    /// Delete this object from persistent storage and the related remote session data. Does not try to delete the backup.
    public func deleteFromKeychain() -> Promise<Void> {
        return firstly {
            when(fulfilled: try BrowserSession.all()
                    .filter({ $0.browser == .cli })
                    .map { $0.deleteAccount(accountId: self.id) }
            )
        }.map { _ in
            try Keychain.shared.delete(id: self.id, service: .sshIdentity)
        }.asVoid()
    }

    // Documentation in protocol
    public func backup() -> Promise<Void> {
        guard algorithm != .ECDSA256 else {
            return .value(())
        }
        let backupObject = BackupSSHIdentity(id: self.id, name: self.name, algorithm: self.algorithm, salt: self.salt.base64, lastChange: self.lastChange)
        return firstly {
            sendData(item: backupObject)
        }.log("Error setting account sync info")
    }

    // Documentation in protocol.
    public mutating func update(with backupObject: BackupSSHIdentity, context: LAContext? = nil) throws -> Bool {
        if self.name != backupObject.name {
            self.name = backupObject.name
            return true
        } else {
            return false
        }
    }

}

public struct BackupSSHIdentity: BackupObject {

    let id: String
    let name: String
    let algorithm: SSHAlgorithm
    let salt: String
    public var lastChange: Timestamp

}
