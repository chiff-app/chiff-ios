//
//  KeychainService.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication

/// Groups keychain objects and determines classification.
enum KeychainService: String {
    case account = "io.keyn.account"
    case sharedAccount = "io.keyn.sharedaccount"
    case otp = "io.keyn.otp"
    case webauthn = "io.keyn.webauthn"
    case notes = "io.keyn.notes"
    case seed = "io.keyn.seed"
    case sharedSessionKey = "io.keyn.session.shared"
    case signingSessionKey = "io.keyn.session.signing"
    case sharedTeamSessionKey = "io.keyn.teamsession.shared"
    case signingTeamSessionKey = "io.keyn.teamsession.signing"
    case aws = "io.keyn.aws"
    case backup = "io.keyn.backup"

    var classification: Classification {
        switch self {
        case .sharedSessionKey, .signingSessionKey, .sharedTeamSessionKey, .signingTeamSessionKey:
            return .restricted
        case .account, .sharedAccount, .webauthn:
            return .confidential
        case .aws, .backup:
            return .secret
        case .seed, .otp, .notes:
            return .topsecret
        }
    }

    /// The `accessGroup` is used to determine whether item are accessible from the extensions.
    var accessGroup: String {
        switch self.classification {
        case .restricted:
            return "35MFYY2JY5.io.keyn.restricted"
        case .confidential:
            return "35MFYY2JY5.io.keyn.confidential"
        case .secret, .topsecret:
            return "35MFYY2JY5.io.keyn.keyn"
        }
    }

    var defaultContext: LAContext? {
        return (self.classification == .confidential || self.classification == .topsecret) ? LocalAuthenticationManager.shared.mainContext : nil
    }

    enum Classification {
        case restricted
        case confidential
        case secret
        case topsecret
    }
}
