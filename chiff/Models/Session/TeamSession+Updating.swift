//
//  TeamSession+Updating.swift
//  chiff
//
//  Created by Bas Doorn on 28/10/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import UIKit
import PromiseKit

extension TeamSession {

    // MARK: - Static methods

    static func updateAllTeamSessions(pushed: Bool) -> Promise<Void> {
        return firstly {
            when(fulfilled: try TeamSession.all().map { updateTeamSession(session: $0, pushed: pushed) })
        }.then { (results) -> Promise<Void> in
            if results.reduce(false, { $0 ? $0 : $1 }) {
                let teamSessions = try TeamSession.all()
                let organisationKey = teamSessions.first?.organisationKey
                let organisationType = teamSessions.first?.type
                let isAdmin = teamSessions.contains(where: { $0.isAdmin })
                return BrowserSession.updateAllSessionData(organisationKey: organisationKey, organisationType: organisationType, isAdmin: isAdmin)
            } else {
                return .value(())
            }
        }
    }

    static func updateTeamSession(session: TeamSession, pushed: Bool = false) -> Promise<Bool> {
        var session = session
        var makeBackup = false
        var changed = false
        if !session.created && pushed {
            session.created = true
            changed = true
            makeBackup = true
        }
        return firstly {
            when(fulfilled: session.getOrganisationData(), API.shared.signedRequest(path: "teams/users/\(session.teamId)/\(session.id)", method: .get, privKey: try session.signingPrivKey()))
        }.then { (type, result) -> Promise<(OrganisationType?, JSONObject, String?)> in
            if let keys = result["keys"] as? [String] {
                return session.updateKeys(keys: keys).map { (type, result, $0) }
            } else {
                return .value((type, result, nil))
            }
        }.map { (type, result, pubKey) in
            try session.update(changed: changed, makeBackup: makeBackup, type: type, result: result, pubKey: pubKey)
        }.recover { (error) -> Promise<Bool> in
            guard case APIError.statusCode(404) = error else {
                throw error
            }
            guard session.created else {
                return .value(false)
            }
            try? session.delete()
            NotificationCenter.default.postMain(name: .sessionEnded, object: nil, userInfo: [NotificationContentKey.sessionId: session.id])
            NotificationCenter.default.postMain(name: .sharedAccountsChanged, object: nil)
            return .value(true)
        }
    }

    mutating func update(changed: Bool, makeBackup: Bool, type: OrganisationType?, result: JSONObject, pubKey: String?) throws -> Bool {
        var changed = changed
        var makeBackup = makeBackup
        if let pubKey = pubKey {
            signingPubKey = pubKey
            changed = true
            if created {
                makeBackup = true
            }
        }
        guard let accounts = result["accounts"] as? [String: String],
              let isAdmin = result["admin"] as? Bool else {
            throw CodingError.missingData
        }
        if let type = type, self.type != type {
            self.type = type
            changed = true
        }
        if self.isAdmin != isAdmin {
            self.isAdmin = isAdmin
            changed = true
        }
        if changed {
            try update(makeBackup: makeBackup)
        }
        let updatedAccounts = try updateSharedAccounts(accounts: accounts)
        if changed || updatedAccounts > 0 {
            NotificationCenter.default.postMain(name: .sharedAccountsChanged, object: nil)
            NotificationCenter.default.postMain(name: .sessionUpdated, object: nil, userInfo: ["session": self, "count": accounts.count])
        }
        return changed
    }

    mutating func updateSharedAccounts(accounts: [String: String]) throws -> Int {
        var changed = 0
        let key = try self.passwordSeed()
        //TODO: If an account already exists because of an earlier session, now throws keyn.KeychainError.unhandledError(-25299). Handle better
        var currentAccounts = try SharedAccount.all(context: nil, label: self.id)
        for (id, data) in accounts {
            currentAccounts.removeValue(forKey: id)
            let ciphertext = try Crypto.shared.convertFromBase64(from: data)
            let (accountData, _)  = try Crypto.shared.decrypt(ciphertext, key: self.sharedKey(), version: self.version)
            if var account = try SharedAccount.get(id: id, context: nil) {
                if try account.sync(accountData: accountData, key: key) {
                    changed += 1
                }
            } else { // New account added
                try SharedAccount.create(accountData: accountData, id: id, key: key, context: nil, sessionId: self.id)
                changed += 1
            }
        }
        for account in currentAccounts.values {
            // TODO: Check how to safely delete here in the background
            try account.deleteSync()
            changed += 1
        }
        Properties.setSharedAccountCount(teamId: self.id, count: accounts.count)
        return changed
    }

    func updateKeys(keys: [String]) -> Promise<String?> {
        do {
            guard let privKey = try Keychain.shared.get(id: SessionIdentifier.sharedKeyPrivKey.identifier(for: id), service: TeamSession.signingService) else {
                throw KeychainError.notFound
            }
            // This loops over all keys, chaining them from the initial key
            let (_, seeds) = try keys.reduce((try self.sharedKey(), nil)) { (data, ciphertext) -> (Data, TeamSessionSeeds) in
                let ciphertextData = try Crypto.shared.convertFromBase64(from: ciphertext)
                let newPubKey = try Crypto.shared.decrypt(ciphertextData, key: data.0, version: self.version).0
                let sharedSeed = try Crypto.shared.generateSharedKey(pubKey: newPubKey, privKey: privKey)
                let seeds = try TeamSessionSeeds(seed: sharedSeed)
                return (seeds.encryptionKey, seeds)
            }
            if let seeds = seeds {
                return firstly {
                    API.shared.signedRequest(path: "teams/users/\(teamId)/\(self.id)",
                                             method: .patch,
                                             privKey: try signingPrivKey(),
                                             message: [
                                                "id": self.id,
                                                "pubKey": signingPubKey,
                                                "length": keys.count,
                                                "newPubKey": seeds.signingKeyPair.pubKey.base64
                                             ])
                }.map { _ in
                    try seeds.update(id: self.id, data: nil)
                    return seeds.signingKeyPair.pubKey.base64
                }
            }
            return .value(nil)
        } catch {
            return Promise(error: error)
        }
    }

    func getOrganisationData() -> Promise<OrganisationType?> {
        let filemgr = FileManager.default
        guard let path = logoPath else {
            return Promise(error: TeamSessionError.logoPathNotFound)
        }
        return firstly { () -> Promise<JSONObject> in
            let organisationKeyPair = try Crypto.shared.createSigningKeyPair(seed: organisationKey)
            return API.shared.signedRequest(path: "organisations/\(organisationKeyPair.pubKey.base64)", method: .get, privKey: organisationKeyPair.privKey)
        }.map { result in
            if let logo = result["logo"] as? String {
                guard let data = Data(base64Encoded: logo, options: .ignoreUnknownCharacters), UIImage(data: data) != nil else {
                    throw CodingError.unexpectedData
                }
                if filemgr.fileExists(atPath: path) {
                    try filemgr.removeItem(atPath: path)
                }
                filemgr.createFile(atPath: path, contents: data, attributes: nil)
            }
            if let typeValue = result["type"] as? Int, let type = OrganisationType(rawValue: typeValue) {
                return type
            } else {
                return nil
            }
        }.recover { (_) -> Promise<OrganisationType?> in
            return .value(nil)
        }
    }

}