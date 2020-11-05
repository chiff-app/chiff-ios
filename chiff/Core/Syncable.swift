//
//  Syncable.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication
import PromiseKit

enum SyncError: Error {
    case dataDeleted
    case webAuthnExists
}

enum SyncEndpoint: String {
    case sessions
    case accounts
}

struct RecoveryResult {
    let succeeded: Int
    let failed: Int
    var total: Int {
        return succeeded + failed
    }
}

protocol BackupObject: Codable {
    var lastChange: Timestamp { get }
}

protocol Syncable {
    associatedtype BackupType: BackupObject

    static var syncEndpoint: SyncEndpoint { get }

    static func create(backupObject: BackupType, context: LAContext?) throws
    static func all(context: LAContext?) throws -> [String: Self]
    static func get(id: String, context: LAContext?) throws -> Self?
    static func notifyObservers()

    func backup() throws -> Promise<Void>
    func deleteSync() throws
    mutating func update(with backupObject: BackupType, context: LAContext?) throws -> Bool

    var id: String { get }
    var lastChange: Timestamp { get set }
}

extension Syncable {

    static func publicKey() throws -> String {
        guard let pubKey = try Keychain.shared.get(id: KeyIdentifier.pub.identifier(for: .backup), service: .backup) else {
            throw KeychainError.notFound
        }
        let base64PubKey = try Crypto.shared.convertToBase64(from: pubKey)
        return base64PubKey
    }

    static func privateKey() throws -> Data {
        guard let privKey = try Keychain.shared.get(id: KeyIdentifier.priv.identifier(for: .backup), service: .backup) else {
            throw KeychainError.notFound
        }
        return privKey
    }

    static func encryptionKey() throws -> Data {
        guard let key = try Keychain.shared.get(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup) else {
            throw KeychainError.notFound
        }
        return key
    }

    static func getData<T: BackupObject>(context: LAContext?) -> Promise<[String: T]> where T == BackupType {
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

    static func sync(context: LAContext?) -> Promise<Void> {
        return firstly { () -> Promise<[String: BackupType]> in
            getData(context: context)
        }.then { (result: [String: BackupType]) -> Promise<Void> in
            var current = try all(context: context)
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
                try object.deleteSync()
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

    func sendData<T: BackupObject>(item: T) -> Promise<Void> where T == BackupType {
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

    func deleteBackup() throws {
        API.shared.signedRequest(path: "users/\(try Self.publicKey())/\(Self.syncEndpoint.rawValue)/\(self.id)",
                                 method: .delete,
                                 privKey: try Self.privateKey(),
                                 message: ["id": self.id])
            .asVoid()
            .catchLog("Cannot delete backup.")
    }

}
