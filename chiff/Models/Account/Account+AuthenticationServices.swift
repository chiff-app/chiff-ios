//
//  Account+AuthenticationServices.swift
//  keyn
//
//  Created by Bas Doorn on 17/03/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation
import AuthenticationServices

extension Account {

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
