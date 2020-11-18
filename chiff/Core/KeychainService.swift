//
//  KeychainService.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication

/// Groups keychain objects and determines classification.
enum KeychainService {
    case account(attribute: AccountAttribute? = nil)
    case sharedAccount(attribute: AccountAttribute? = nil)
    case seed
    case browserSession(attribute: SessionAttribute)
    case teamSession(attribute: SessionAttribute)
    case aws
    case backup

    enum AccountAttribute: String {
        case otp
        case webauthn
        case notes
    }

    enum SessionAttribute: String {
        case sharedKey = "shared"
        case signingKey = "signing"
    }

    enum Classification {
        case restricted
        case confidential
        case secret
        case topsecret
    }

    var service: String {
        switch self {
        case .account(let attribute):
            if let attribute = attribute {
                return "io.keyn.account.\(attribute)"
            } else {
                return "io.keyn.account"
            }
        case .sharedAccount(let attribute):
            if let attribute = attribute {
                return "io.keyn.sharedaccount.\(attribute)"
            } else {
                return "io.keyn.sharedaccount"
            }
        case .browserSession(let attribute):
            return "io.keyn.session.\(attribute)"
        case .teamSession(let attribute):
            return "io.keyn.teamsession.\(attribute)"
        case .seed:
            return "io.keyn.seed"
        case .aws:
            return "io.keyn.aws"
        case .backup:
            return "io.keyn.backup"
        }
    }

    var classification: Classification {
        switch self {
        case .browserSession, .teamSession:
            return .restricted
        case .account(let attribute), .sharedAccount(let attribute):
            switch attribute {
            case .otp, .notes:
                return .topsecret
            default:
                return .confidential
            }
        case .aws, .backup:
            return .secret
        case .seed:
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

}
