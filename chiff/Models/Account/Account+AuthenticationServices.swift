//
//  Account+AuthenticationServices.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import AuthenticationServices

extension Account {

    /// Save this account to the IdentityStore, so it is available for AutoFill.
    func saveToIdentityStore() {
        if #available(iOS 12.0, *) {
            ASCredentialIdentityStore.shared.getState { (state) in
                if !state.isEnabled {
                    return
                } else if state.supportsIncrementalUpdates {
                    let service = ASCredentialServiceIdentifier(identifier: self.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                    let identity = ASPasswordCredentialIdentity(serviceIdentifier: service, user: self.username, recordIdentifier: self.id)
                    ASCredentialIdentityStore.shared.saveCredentialIdentities([identity], completion: nil)
                } else if let accounts = try? Self.all(context: nil) {
                    let identities = accounts.values.map { (account) -> ASPasswordCredentialIdentity in
                        let service = ASCredentialServiceIdentifier(identifier: account.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                        return ASPasswordCredentialIdentity(serviceIdentifier: service, user: account.username, recordIdentifier: account.id)
                    }
                    ASCredentialIdentityStore.shared.saveCredentialIdentities(identities, completion: nil)
                }
            }
        }
    }

    /// Delete this account from the IdentityStore, so it is no longer available for Autofill
    func deleteFromToIdentityStore() {
        if #available(iOS 12.0, *) {
            ASCredentialIdentityStore.shared.getState { (state) in
                if !state.isEnabled {
                    return
                } else if state.supportsIncrementalUpdates {
                    let service = ASCredentialServiceIdentifier(identifier: self.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                    let identity = ASPasswordCredentialIdentity(serviceIdentifier: service, user: self.username, recordIdentifier: self.id)
                    ASCredentialIdentityStore.shared.removeCredentialIdentities([identity], completion: nil)
                } else {
                    Self.reloadIdentityStore()
                }
            }
        }
    }

    /// Reload all accounts into the identity store.
    @available(iOS 12.0, *)
    static func reloadIdentityStore() {
        ASCredentialIdentityStore.shared.removeAllCredentialIdentities({ (result, error) in
            if let error = error {
                Logger.shared.error("Error deleting credentials from identity store", error: error)
            } else if result, let accounts = try? Self.all(context: nil) {
                let identities = accounts.values.map { (account) -> ASPasswordCredentialIdentity in
                    let service = ASCredentialServiceIdentifier(identifier: account.site.url, type: ASCredentialServiceIdentifier.IdentifierType.URL)
                    return ASPasswordCredentialIdentity(serviceIdentifier: service, user: account.username, recordIdentifier: account.id)
                }
                ASCredentialIdentityStore.shared.saveCredentialIdentities(identities, completion: nil)
            }
        })
    }
}
