//
//  PasskeyRegistrationRequest.swift
//  chiffCredentialProvider
//
//  Copyright: see LICENSE.md
//

import Foundation
import AuthenticationServices
import ChiffCore

/// A PassKey registration request
struct PasskeyRegistrationRequest {
    let clientDataHash: Data
    let relyingPartyIdentifier: String
    let userHandle: Data
    let userName: String
    let serviceIdentifier: ASCredentialServiceIdentifier
    let algorithms: [WebAuthnAlgorithm]
}
