//
//  Syncable.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication
import PromiseKit

public enum SyncError: Error {
    case dataDeleted
    case webAuthnExists
}

public enum SyncEndpoint: String {
    case sessions
    case accounts
    case sshkeys
}

public struct RecoveryResult {
    public let succeeded: Int
    public let failed: Int
    public var total: Int {
        return succeeded + failed
    }
}

public protocol BackupObject: Codable {
    var lastChange: Timestamp { get }
}

/// Conforming to `Syncable` means the object may be updated if the remote data changes.
public protocol Syncable {
    associatedtype BackupType: BackupObject

    var id: String { get }
    var lastChange: Timestamp { get set }
    // If this is false, the object is not synced.
    var sync: Bool { get }

    static var syncEndpoint: SyncEndpoint { get }

    /// This should persistently create a new object.
    /// - Parameters:
    ///   - backupObject: The backup data that should be used to create the object.
    ///   - context: Optionally, the `LAContext` for authentication.
    static func create(backupObject: BackupType, context: LAContext?) throws

    /// Retrieve a dictionary of all objects from persistent storage.
    /// - Parameter context: Optionally, the `LAContext` for authentication.
    static func all(context: LAContext?) throws -> [String: Self]

    /// Retrieve a single objects from persistent storage
    /// - Parameters:
    ///   - id: The *id* of the object that should be retrieved.
    ///   - context: Optionally, the `LAContext` for authentication.
    static func get(id: String, context: LAContext?) throws -> Self?

    /// This function notifies observers that relevant data has changed.
    static func notifyObservers()

    /// Create a backup and return when finished.
    func backup() throws -> Promise<Void>

    /// Delete this object from persistent storage and the related remote session data. Does not try to delete the backup.
    func deleteFromKeychain() -> Promise<Void>

    /// Update the object with the data from the backupObject.
    /// Only updates attributes that have changed.
    /// - Parameters:
    ///   - backupObject: The backup data.
    ///   - context: Optionally, the `LAContext` for authentication.
    mutating func update(with backupObject: BackupType, context: LAContext?) throws -> Bool

}

extension Syncable {

    /// Provides the backup server public key to the objects that conform to `Syncable`.
    /// - Throws: `KeychainError.notFound` if the public key is not found.
    /// - Returns: The base64-encoded public key.
    static func publicKey() throws -> String {
        guard let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) else {
            throw KeychainError.notFound
        }

        return pubKey.base64
    }

    /// Provides the backup server private key to the objects that conform to `Syncable`.
    /// - Throws: `KeychainError.notFound` if the private key is not found.
    /// - Returns: The private key.
    public static func privateKey() throws -> Data {
        guard let privKey = try Keychain.shared.get(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup) else {
            throw KeychainError.notFound
        }

        return privKey
    }

    /// Provides the backup encryption key to the objects that conform to `Syncable`.
    /// - Throws: `KeychainError.notFound` if the key is not found.
    /// - Returns: The encryption key.
    static func encryptionKey() throws -> Data {
        guard let key = try Keychain.shared.get(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup) else {
            throw KeychainError.notFound
        }

        return key
    }

    /// Retrieve all backup objects from the remote server and decrypts them.
    ///
    /// Then checks for each if:
    /// * The local object does not exists yet. If so, create.
    /// * The local object does exists, but is older. If so, update.
    /// * The local object does exist, but is newer. If so, backup.
    /// * The local object does exist and has same age. If so, do nothing.
    ///
    /// In addition, if the are any local objects that are not present remotely, they are deleted.
    ///
    /// - Parameter context: Optionally, the `LAContext` for authentication.
    public static func sync(context: LAContext?) -> Promise<Void> {
        return firstly { () -> Promise<[String: BackupType]> in
            getData(context: context)
        }.then { (result: [String: BackupType]) -> Promise<Void> in
            var current = try all(context: context).filter { $0.value.sync }
            var promises: [Promise<Void>] = []
            var changed = result.reduce(false) { (changed, item) -> Bool in
                do {
                    let (id, backupObject) = item
                    if var object = try get(id: id, context: context) {
                        current.removeValue(forKey: object.id)
                        if backupObject.lastChange == object.lastChange {
                            // Synced
                            return changed
                        } else if backupObject.lastChange > object.lastChange {
                            // Backup object is newer, update
                            let updated = try object.update(with: backupObject, context: context)
                            return changed || updated
                        } else {
                            // Local account is newer, create backup.
                            promises.append(try object.backup())
                            return changed
                        }
                    } else {
                        // Item doesn't exist, create.
                        try Self.create(backupObject: backupObject, context: context)
                        return true
                    }
                } catch {
                    Logger.shared.error("Could not restore data.", error: error)
                    return changed
                }
            }
            // Remove accounts that were not present
            for object in current.values {
                promises.append(object.deleteFromKeychain())
                changed = true
            }
            if changed {
                notifyObservers()
            }
            return when(fulfilled: promises)
        }.recover { error in
            switch error {
            case KeychainError.interactionNotAllowed:
                return // Probably happend in the background, we'll sync when authenticated again
            case APIError.statusCode(404):
                throw SyncError.dataDeleted
            default:
                throw error
            }
        }.log("Syncing error")
    }

    /// Restore objects from backup data. Return a `RecoveryResult` object, which contains information about how many objects succeeded and how many failed.
    ///
    /// The objects are directly stored into persistent storage.
    /// - Parameter context: Optionally, the `LAContext` for authentication.
    /// - Returns: A `RecoveryResult` object.
    static func restore(context: LAContext) -> Promise<RecoveryResult> {
        return firstly { () -> Promise<[String: BackupType]> in
            getData(context: context)
        }.map { result in
            var succeeded = 0
            var failed = 0
            for data in result.values {
                do {
                    try Self.create(backupObject: data, context: context)
                    succeeded += 1
                } catch {
                    failed += 1
                    Logger.shared.error("Could not restore data.", error: error)
                }
            }
            return RecoveryResult(succeeded: succeeded, failed: failed)
        }
    }

    /// Send data to the backup server.
    /// - Parameter item: The object that should be encrypted and sent.
    func sendData<T: BackupObject>(item: T) -> Promise<Void> where T == BackupType {
        guard sync else { return .value(()) }
        do {
            let data = try JSONEncoder().encode(item)
            let ciphertext = try Crypto.shared.encryptSymmetric(data.compress() ?? data, secretKey: try Self.encryptionKey())
            let message = [
                "id": self.id,
                "data": ciphertext.base64
            ]
            let path = "users/\(try Self.publicKey())/\(Self.syncEndpoint.rawValue)/\(self.id)"
            return firstly {
                API.shared.signedRequest(path: path, method: .put, privKey: try Self.privateKey(), message: message)
            }.asVoid().log("BackupManager cannot backup data.")
        } catch {
            return Promise(error: error)
        }
    }

    /// Delete a backup objects.
    /// - Throws: `KeychainError.notFound` if one of the keys cannot be not found.
    func deleteBackup() -> Promise<Void> {
        guard sync else { return .value(()) }
        return firstly {
            API.shared.signedRequest(path: "users/\(try Self.publicKey())/\(Self.syncEndpoint.rawValue)/\(self.id)",
                                     method: .delete,
                                     privKey: try Self.privateKey(),
                                     message: ["id": self.id])
        }.asVoid().log("Cannot delete backup.")
    }

    // MARK: - Private functions

    /// Retrieve all backup objects from the remote server and decrypt them.
    /// - Parameter context: Optionally, the `LAContext` for authentication.
    /// - Returns: A dictionary of the retrieved objects.
    private static func getData<T: BackupObject>(context: LAContext?) -> Promise<[String: T]> where T == BackupType {
        return firstly {
            API.shared.signedRequest(path: "users/\(try publicKey())/\(syncEndpoint.rawValue)", method: .get, privKey: try privateKey())
        }.map { result in
            let key = try encryptionKey()
            return result.compactMapValues { (object) in
                do {
                    guard let ciphertext = (object as? String)?.fromBase64 else {
                        throw CodingError.unexpectedData
                    }
                    let data = try Crypto.shared.decryptSymmetric(ciphertext, secretKey: key)
                    return try JSONDecoder().decode(T.self, from: data.decompress() ?? data)
                } catch {
                    Logger.shared.error("Could not get restore data.", error: error)
                }
                return nil
            }
        }.log("Failed to get backup data.")
    }

}
