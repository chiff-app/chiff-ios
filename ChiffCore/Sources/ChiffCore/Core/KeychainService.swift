//
//  KeychainService.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation
import LocalAuthentication

/// Groups keychain objects and determines classification.
public enum KeychainService {
    case account(attribute: AccountAttribute? = nil)
    case sharedAccount(attribute: AccountAttribute? = nil)
    case sshIdentity
    case seed
    case webAuthnSeed
    case passwordSeed
    case browserSession(attribute: SessionAttribute)
    case teamSession(attribute: SessionAttribute)
    case aws
    case backup

    public enum AccountAttribute: String {
        case otp
        case webauthn
        case notes
    }

    public enum SessionAttribute: String {
        case shared
        case signing
    }

    enum Classification {
        case confidential   // kSecAttrAccessibleAfterFirstUnlock
        case secret         // kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        case topsecret      // user presence required
    }

    public var service: String {
        switch self {
        case .account(let attribute):
            if let attribute = attribute {
                return "io.keyn.account.\(attribute.rawValue)"
            } else {
                return "io.keyn.account"
            }
        case .sharedAccount(let attribute):
            if let attribute = attribute {
                return "io.keyn.sharedaccount.\(attribute.rawValue)"
            } else {
                return "io.keyn.sharedaccount"
            }
        case .sshIdentity:
            return "io.keyn.ssh"
        case .browserSession(let attribute):
            return "io.keyn.session.\(attribute.rawValue)"
        case .teamSession(let attribute):
            return "io.keyn.teamsession.\(attribute.rawValue)"
        case .seed, .passwordSeed, .webAuthnSeed:
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
            return .confidential
        case .aws, .backup:
            return .secret
        default:
            return .topsecret
        }
    }

    /// The `accessGroup` is used to determine whether item are accessible from the extensions.
    public var accessGroup: String {
        switch self {
        case .browserSession, .teamSession:
            return "35MFYY2JY5.io.keyn.restricted"      // Shared with notificationExtension and credentialProvider
        case .account, .sharedAccount, .backup, .passwordSeed, .webAuthnSeed:
            return "group.app.chiff.chiff"              // Shared with credentialProvider
        case .aws, .seed, .sshIdentity:
            return "35MFYY2JY5.io.keyn.keyn"            // Chiff only
        }
    }

    var defaultContext: LAContext? {
        return (self.classification == .secret || self.classification == .topsecret) ? LocalAuthenticationManager.shared.mainContext : nil
    }

}
