//
//  Seed+BetaMigration.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import PromiseKit

extension Seed {

    /// Move this seed from the beta environment to the production environment.
    static func moveToProduction() -> Promise<Void> {
        do {
            guard Properties.environment == .beta && !Properties.migrated else {
                return .value(())
            }
            let teamSessions = try TeamSession.all()
            let organisationKey = teamSessions.first?.organisationKey
            let organisationType = teamSessions.first?.type
            let isAdmin = teamSessions.contains(where: { $0.isAdmin })
            let message = [
                "sessions": try BrowserSession.all().map { [
                    "pk": $0.signingPubKey,
                    "message": try Crypto.shared.sign(message: JSONSerialization.data(withJSONObject: [
                            "timestamp": Date.now,
                            "data": try $0.encryptSessionData(organisationKey: organisationKey, organisationType: organisationType, isAdmin: isAdmin, migrated: true)
                        ], options: []), privKey: try $0.signingPrivKey()).base64
                    ]
                }
            ]
            return firstly {
                API.shared.signedRequest(path: "users/\(try publicKey())", method: .patch, privKey: try privateKey(), message: message)
            }.asVoid().done {
                Properties.migrated = true
            }
        } catch {
            return Promise(error: error)
        }
    }

    /// Determine whether this seed already has been migrated or not.
    static func setMigrated() -> Promise<Void> {
        guard Properties.environment == .beta else {
            return .value(())
        }
        return firstly {
            API.shared.signedRequest(path: "users/\(try publicKey())/migrated", method: .get, privKey: try privateKey())
        }.map { result in
            guard let migrated = result["migrated"] as? Bool else {
                Logger.shared.warning("Error parsing migrated status")
                return
            }
            Properties.migrated = migrated
        }.asVoid().recover { error in
            guard case APIError.statusCode(404) = error else {
                Logger.shared.warning("Error getting migrated status")
                return
            }
            return
        }
    }

}
