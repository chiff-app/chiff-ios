//
//  KeynRequest.swift
//  keyn
//
//  Created by Bas Doorn on 17/03/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import Foundation

/**
 * Keyn Requests.
 *
 * Direction: browser -> app
 */
struct KeynRequest: Codable {
    let accountID: String?
    let accountIDs: [Int: String]?
    let browserTab: Int?
    let challenge: String?
    let password: String?
    let passwordSuccessfullyChanged: Bool?
    let siteID: String?
    let siteName: String?
    let newSiteName: String?
    let siteURL: String?
    let notes: String?
    let type: KeynMessageType
    let relyingPartyId: String?
    let algorithms: [WebAuthnAlgorithm]?
    let username: String?
    let sentTimestamp: TimeInterval
    let count: Int?
    let askToChange: Bool?
    var sessionID: String?
    var accounts: [BulkAccount]?

    enum CodingKeys: String, CodingKey {
        case accountID = "a"
        case accountIDs = "an"
        case browserTab = "b"
        case challenge = "c"
        case password = "p"
        case passwordSuccessfullyChanged = "v"
        case sessionID = "i"
        case siteID = "s"
        case siteName = "n"
        case newSiteName = "nn"
        case siteURL = "l"
        case notes = "y"
        case type = "r"
        case algorithms = "g"
        case relyingPartyId = "rp"
        case username = "u"
        case sentTimestamp = "z"
        case count = "x"
        case accounts = "t"
        case askToChange = "d"
    }

    /// This checks if the appropriate variables are set for the type of of this request
    func verifyIntegrity() -> Bool {
        switch type {
        case .add, .addAndLogin:
            guard siteID != nil else {
                Logger.shared.error("VerifyIntegrity failed because there is no site ID.")
                return false
            }
            guard password != nil else {
                Logger.shared.error("VerifyIntegrity failed because there is no password.")
                return false
            }
            guard username != nil else {
                Logger.shared.error("VerifyIntegrity failed because there is no username.")
                return false
            }
        case .login, .change, .fill:
            guard accountID != nil else {
                Logger.shared.error("VerifyIntegrity failed because there is no accountID.")
                return false
            }
        case .addToExisting:
            guard siteID != nil else {
                Logger.shared.error("VerifyIntegrity failed because there is no site ID.")
                return false
            }
            guard accountID != nil else {
                Logger.shared.error("VerifyIntegrity failed because there is no accountID.")
                return false
            }
        case .addBulk:
            guard count != nil else {
                Logger.shared.error("VerifyIntegrity failed because there is no account count.")
                return false
            }
            return true // Return here because subsequent don't apply to addBulk request
        case .adminLogin:
            guard browserTab != nil else {
                Logger.shared.error("VerifyIntegrity failed because there is no browser tab.")
                return false
            }
            return true // Return here because subsequent don't apply to adminLogin request
        case .webauthnLogin:
            guard challenge != nil else {
                Logger.shared.error("VerifyIntegrity failed because there is no webauthn challenge.")
                return false
            }
            guard relyingPartyId != nil else {
                Logger.shared.error("VerifyIntegrity failed because there is no webauthn relying party ID.")
                return false
            }
        case .bulkLogin:
            guard accountIDs != nil else {
                Logger.shared.error("VerifyIntegrity failed because there are not accountIds")
                return false
            }
            return true // Return here because subsequent don't apply to adminLogin request
        case .webauthnCreate:
            guard relyingPartyId != nil else {
                Logger.shared.error("VerifyIntegrity failed because there is no webauthn relying party ID.")
                return false
            }
            guard let algorithms = algorithms, !algorithms.isEmpty else {
                Logger.shared.error("VerifyIntegrity failed because there is no webauthn algorithm.")
                return false
            }
        case .getDetails, .updateAccount:
            guard accountID != nil else {
                Logger.shared.error("VerifyIntegrity failed because there is no accountID.")
                return false
            }
            guard browserTab != nil else {
                Logger.shared.warning("VerifyIntegrity failed because there is no browserTab to send the reply back to.")
                return false
            }
            guard siteName != nil else {
                Logger.shared.error("VerifyIntegrity failed because there is no siteName.")
                return false
            }
            return true // Return here because getDetails doesn't have siteUrl don't apply to adminLogin request
        default:
            Logger.shared.warning("Unknown request received", userInfo: ["type": type])
            return false
        }

        // These checks apply to all accept addBulk
        guard browserTab != nil else {
            Logger.shared.warning("VerifyIntegrity failed because there is no browserTab to send the reply back to.")
            return false
        }
        guard siteName != nil else {
            Logger.shared.error("VerifyIntegrity failed because there is no siteName.")
            return false
        }
        guard siteURL != nil else {
            Logger.shared.error("VerifyIntegrity failed because there is no siteURL.")
            return false
        }

        return true
    }
}
