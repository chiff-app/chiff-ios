//
//  Account+AuthenticationServices.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import AuthenticationServices

extension Account {

    /// Save this account to the IdentityStore, so it is available for AutoFill.
    func saveToIdentityStore() {
        ASCredentialIdentityStore.shared.getState { (state) in
            guard state.isEnabled else {
                return
            }
            guard state.supportsIncrementalUpdates else {
                Self.saveCredentialIdentities()
                return
            }
            if #available(iOS 17.0, *), let webAuthn = (self as? UserAccount)?.webAuthn {
                let identity = ASPasskeyCredentialIdentity(relyingPartyIdentifier: webAuthn.id, userName: self.username, credentialID: self.id.fromHex!, userHandle: webAuthn.userHandle?.data ?? Data())
                ASCredentialIdentityStore.shared.saveCredentialIdentities([identity], completion: nil)
            }
            if hasPassword {
                let service = ASCredentialServiceIdentifier(identifier: self.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                let identity = ASPasswordCredentialIdentity(serviceIdentifier: service, user: self.username, recordIdentifier: self.id)
                ASCredentialIdentityStore.shared.saveCredentialIdentities([identity], completion: nil)
            }
        }
    }

    /// Delete this account from the IdentityStore, so it is no longer available for Autofill
    func deleteFromToIdentityStore() {
        ASCredentialIdentityStore.shared.getState { (state) in
            guard state.isEnabled else {
                return
            }
            guard state.supportsIncrementalUpdates else {
                Self.saveCredentialIdentities()
                return
            }
            if #available(iOS 17.0, *), let webAuthn = (self as? UserAccount)?.webAuthn {
                let identity = ASPasskeyCredentialIdentity(relyingPartyIdentifier: webAuthn.id, userName: self.username, credentialID: self.id.fromHex!, userHandle: webAuthn.userHandle?.data ?? Data())
                ASCredentialIdentityStore.shared.removeCredentialIdentities([identity], completion: nil)
            }
            if hasPassword {
                let service = ASCredentialServiceIdentifier(identifier: self.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                let identity = ASPasswordCredentialIdentity(serviceIdentifier: service, user: self.username, recordIdentifier: self.id)
                ASCredentialIdentityStore.shared.removeCredentialIdentities([identity], completion: nil)
            }
        }
    }
    
    @available(iOS 26.0, *)
    func toASImportableItem() throws -> ASImportableItem {
        var credentials = [ASImportableCredential]()
        if let webAuthn = (self as? UserAccount)?.webAuthn {
            let privKey = try webAuthn.getPrivKey(accountId: self.id)
            let passkey = ASImportableCredential.Passkey(credentialID: self.id.fromHex!, relyingPartyIdentifier: webAuthn.id, userName: self.username, userDisplayName: self.site.name, userHandle: webAuthn.userHandle?.data ?? Data(), key: privKey)
            credentials.append(ASImportableCredential.passkey(passkey))
        }
        if let password = try password() {
            let passwordField = ASImportableEditableField(id: nil, fieldType: .concealedString, value: password)
            let usernameField = ASImportableEditableField(id: nil, fieldType: .string, value: self.username)
            let passwordItem = ASImportableCredential.BasicAuthentication(userName: usernameField, password: passwordField)
            credentials.append(ASImportableCredential.basicAuthentication(passwordItem))
        }
        if let token = try oneTimePasswordToken() {
            let algorithm: ASImportableCredential.TOTP.Algorithm
            switch token.generator.algorithm {
            case .sha1:
                algorithm = ASImportableCredential.TOTP.Algorithm.sha1
            case .sha256:
                algorithm = ASImportableCredential.TOTP.Algorithm.sha256
            case .sha512:
                algorithm = ASImportableCredential.TOTP.Algorithm.sha512
            }
            let totpItem = ASImportableCredential.TOTP(secret: token.generator.secret, period: 30, digits: UInt16(token.generator.digits), userName: nil, algorithm: algorithm, issuer: token.issuer)
            credentials.append(ASImportableCredential.totp(totpItem))
        }
        if let notes = try self.notes() {
            let noteData = ASImportableEditableField(id: nil, fieldType: .string, value: notes)
            let note = ASImportableCredential.Note(content: noteData)
            credentials.append(ASImportableCredential.note(note))
        }
        return ASImportableItem(id: self.id.fromHex!, created: Date(), lastModified: Date(), title: self.site.name, credentials: credentials)
    }

    /// Reload all accounts into the identity store.
    @available(iOS 26.0, *)
    public static func toASImportableAccount() throws -> ASImportableAccount? {
        let accounts = try Self.all(context: nil)
        let items = try Array(accounts.mapValues{ try $0.toASImportableItem() }.values)
        return ASImportableAccount(id: Properties.userId!.data, userName: "", email: "", collections: [], items: items)
    }
    
    public static func reloadIdentityStore() {
        ASCredentialIdentityStore.shared.getState { (state) in
            guard state.isEnabled else {
                return
            }
            ASCredentialIdentityStore.shared.removeAllCredentialIdentities({ (result, error) in
                if let error = error {
                    Logger.shared.error("Error deleting credentials from identity store", error: error)
                } else if result {
                    saveCredentialIdentities()
                }
            })
        }
    }
    
    private static func saveCredentialIdentities() {
        guard let accounts = try? Self.all(context: nil) else {
            return
        }
        if #available(iOS 17.0, *) {
            var identities = [ASCredentialIdentity]()
            for account in accounts.values {
                if let webAuthn = (account as? UserAccount)?.webAuthn {
                    identities.append(ASPasskeyCredentialIdentity(relyingPartyIdentifier: webAuthn.id, userName: account.username, credentialID: account.id.fromHex!, userHandle: webAuthn.userHandle?.data ?? Data()))
                }
                if account.hasPassword {
                    let service = ASCredentialServiceIdentifier(identifier: account.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                    identities.append(ASPasswordCredentialIdentity(serviceIdentifier: service, user: account.username, recordIdentifier: account.id))
                }
            }
            ASCredentialIdentityStore.shared.saveCredentialIdentities(identities, completion: nil)
        } else {
            let identities = accounts.values.compactMap { (account) -> ASPasswordCredentialIdentity? in
                guard account.hasPassword else {
                    return nil
                }
                let service = ASCredentialServiceIdentifier(identifier: account.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                return ASPasswordCredentialIdentity(serviceIdentifier: service, user: account.username, recordIdentifier: account.id)
            }
            ASCredentialIdentityStore.shared.saveCredentialIdentities(identities, completion: nil)
        }
    }
    
}
