//
//  Restorable.swift
//  keyn
//
//  Created by Bas Doorn on 17/03/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation
import LocalAuthentication
import PromiseKit

enum BackupEndpoint: String {
    case sessions = "sessions"
    case accounts = "accounts"
}

protocol Restorable {
    static var backupEndpoint: BackupEndpoint { get }
    static func getBackupData(pubKey: String, context: LAContext) -> Promise<(Int, Int)>
    static func restore(data: Data, id: String, context: LAContext?) throws -> Self

    var id: String { get }
    func deleteBackup() throws
}

extension Restorable {

    func backup(data: Data) -> Guarantee<Bool> {
        do {
            guard let key = try Keychain.shared.get(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup) else {
                throw KeychainError.notFound
            }
            let ciphertext = try Crypto.shared.encryptSymmetric(data, secretKey: key)

            let message = [
                "id": self.id,
                "data": ciphertext.base64
            ]
            let path = "users/\(try BackupManager.publicKey())/\(Self.backupEndpoint.rawValue)/\(self.id)"
            return firstly {
                API.shared.signedRequest(method: .put, message: message, path: path, privKey: try BackupManager.privateKey(), body: nil)
            }.map { _ in
                return true
            }.recover { (error) -> Guarantee<Bool> in
                Logger.shared.error("BackupManager cannot backup data.", error: error)
                return .value(false)
            }
        } catch {
            return .value(false)
        }
    }

    func deleteBackup() throws {
        API.shared.signedRequest(method: .delete, message: ["id": self.id], path: "users/\(try BackupManager.publicKey())/\(Self.backupEndpoint.rawValue)/\(self.id)", privKey: try BackupManager.privateKey(), body: nil).asVoid().catchLog("BackupManager cannot delete account.")
    }

    static func getBackupData(pubKey: String, context: LAContext) -> Promise<(Int, Int)> {
        return firstly {
            API.shared.signedRequest(method: .get, message: nil, path: "users/\(pubKey)/\(backupEndpoint.rawValue)", privKey: try BackupManager.privateKey(), body: nil)
        }.map { result in
            var failed = [String]()
            let objects = result.compactMap { (id, data) -> Self? in
                if let base64Data = data as? String {
                    do {
                        let ciphertext = try Crypto.shared.convertFromBase64(from: base64Data)
                        guard let key = try Keychain.shared.get(id: KeyIdentifier.encryption.identifier(for: .backup), service: .backup) else {
                            throw KeychainError.notFound
                        }
                        let data = try Crypto.shared.decryptSymmetric(ciphertext, secretKey: key)
                        return try Self.restore(data: data, id: id, context: context)
                    } catch {
                        failed.append(id)
                        Logger.shared.error("Could not restore data.", error: error)
                    }
                }
                return nil
            }
            return (objects.count, failed.count)
        }.log("BackupManager cannot get backup data.")
    }

}

