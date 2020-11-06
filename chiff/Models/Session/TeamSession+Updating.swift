//
//  TeamSession+Updating.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import PromiseKit

extension TeamSession {

    // MARK: - Static methods

    static func updateAllTeamSessions() -> Promise<Void> {
        return firstly {
            when(fulfilled: try TeamSession.all().map { updateTeamSession(session: $0) })
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

    static func updateTeamSession(session: TeamSession) -> Promise<Bool> {
        var session = session
        return firstly {
            when(fulfilled:
                    session.getOrganisationData(),
                    API.shared.signedRequest(path: "teams/users/\(session.teamId)/\(session.id)", method: .get, privKey: try session.signingPrivKey()))
        }.then { (type, result) -> Promise<(OrganisationType?, JSONObject, String?)> in
            if let keys = result["keys"] as? [String] {
                return session.updateKeys(keys: keys).map { (type, result, $0) }
            } else {
                return .value((type, result, nil))
            }
        }.map { (type, result, pubKey) in
            try session.update(type: type, result: result, pubKey: pubKey)
        }.recover { (error) -> Promise<Bool> in
            if case APIError.statusCode(404) = error {
                try? session.delete()
                NotificationCenter.default.postMain(name: .sessionEnded, object: nil, userInfo: [NotificationContentKey.sessionID.rawValue: session.id])
                NotificationCenter.default.postMain(name: .sharedAccountsChanged, object: nil)
                return .value(true)
            } else {
                throw error
            }
        }
    }

    mutating func update(type: OrganisationType?, result: JSONObject, pubKey: String?) throws -> Bool {
        var changed = false
        var makeBackup = false
        if let pubKey = pubKey {
            signingPubKey = pubKey
            changed = true
            makeBackup = self.created // Only updated the backup if the session is created.
        }
        guard let created = result["created"] as? Bool,
              let accounts = result["accounts"] as? [String: String],
              let isAdmin = result["admin"] as? Bool else {
            throw CodingError.missingData
        }
        if let type = type, self.type != type {
            self.type = type
            changed = true
        }
        if !self.created && created {
            self.created = true
            changed = true
            makeBackup = true
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
        guard LocalAuthenticationManager.shared.isAuthenticated else {
            return 0 // We're probably in the background, so updating accounts will fail. We'll sync next app is launched.
        }
        var changed = 0
        let key = try self.passwordSeed()
        var currentAccounts = try SharedAccount.all(context: nil, label: self.id)
        for (id, data) in accounts {
            currentAccounts.removeValue(forKey: id)
            let ciphertext = try Crypto.shared.convertFromBase64(from: data)
            let accountData  = try Crypto.shared.decrypt(ciphertext, key: self.sharedKey(), version: self.version)
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
                let newPubKey = try Crypto.shared.decrypt(ciphertextData, key: data.0, version: self.version)
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
