//
//  PasskeyAssertionRequest.swift
//  chiffCredentialProvider
//
//  Copyright: see LICENSE.md
//

import Foundation

// A Passkey assertion request
struct PasskeyAssertionRequest {
    let clientDataHash: Data
    let relyingPartyIdentifier: String
}
