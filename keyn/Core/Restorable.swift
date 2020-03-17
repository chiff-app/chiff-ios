//
//  Restorable.swift
//  keyn
//
//  Created by Bas Doorn on 17/03/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation
import LocalAuthentication

enum BackupEndpoint: String {
    case sessions = "sessions"
    case accounts = "accounts"
}

protocol Restorable {
    static var backupEndpoint: BackupEndpoint { get }
    static func getBackupData(pubKey: String, context: LAContext, completionHandler: @escaping (Result<(Int,Int), Error>) -> Void)
    static func restore(data: Data, id: String, context: LAContext?) throws -> Self

    var id: String { get }
    func deleteBackup() throws
}

extension Restorable {

    func backup(data: Data, completionHandler: @escaping (_ result: Bool) -> Void) {
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
            API.shared.signedRequest(method: .put, message: message, path: path, privKey: try BackupManager.privateKey(), body: nil) { result in
                switch result {
                case .success(_):
                    completionHandler(true)
                case .failure(let error):
                    Logger.shared.error("BackupManager cannot backup data.", error: error)
                    completionHandler(false)
                }
            }
        } catch {
            completionHandler(false)
        }
    }

    func deleteBackup() throws {
        API.shared.signedRequest(method: .delete, message: ["id": self.id], path: "users/\(try BackupManager.publicKey())/\(Self.backupEndpoint.rawValue)/\(self.id)", privKey: try BackupManager.privateKey(), body: nil) { result in
            if case let .failure(error) = result {
                Logger.shared.error("BackupManager cannot delete account.", error: error)
            }
        }
    }

    static func getBackupData(pubKey: String, context: LAContext, completionHandler: @escaping (Result<(Int,Int), Error>) -> Void) {
        do {
            API.shared.signedRequest(method: .get, message: nil, path: "users/\(pubKey)/\(backupEndpoint.rawValue)", privKey: try BackupManager.privateKey(), body: nil) { result in
                switch result {
                case .success(let dict):
                    var failed = [String]()
                    let objects = dict.compactMap { (id, data) -> Self? in
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
                    completionHandler(.success((objects.count, failed.count)))
                case .failure(let error):
                    Logger.shared.error("BackupManager cannot get backup data.", error: error)
                    completionHandler(.failure(error))
                }
            }
        } catch {
            completionHandler(.failure(error))
        }
    }

}

