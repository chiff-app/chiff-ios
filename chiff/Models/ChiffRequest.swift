//
//  ChiffRequest.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation

/**
 * Keyn Requests.
 *
 * Direction: browser -> app
 */
struct ChiffRequest: Codable {
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
    let orderKey: String?
    let organisationName: String?
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
        case orderKey = "o"
        case organisationName = "on"
    }
}
