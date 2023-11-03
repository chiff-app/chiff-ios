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

    /// Reload all accounts into the identity store.
    public static func reloadIdentityStore() {
        ASCredentialIdentityStore.shared.removeAllCredentialIdentities({ (result, error) in
            if let error = error {
                Logger.shared.error("Error deleting credentials from identity store", error: error)
            } else if result {
                saveCredentialIdentities()
            }
        })
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
