//
//  ChiffCoreRequest.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation

/// Request received from clients. Direction browser -> app.
public struct ChiffRequest: Codable {
    public let accountID: String?
    public let accountIDs: [Int: String]?
    public let browserTab: Int?
    public let challenge: String?
    public let password: String?
    public let passwordSuccessfullyChanged: Bool?
    public let siteID: String?
    public let siteName: String?
    public let newSiteName: String?
    public let siteURL: String?
    public let notes: String?
    public let type: ChiffMessageType
    public let relyingPartyId: String?
    public let algorithms: [WebAuthnAlgorithm]?
    public let username: String?
    public let sentTimestamp: Timestamp
    public let count: Int?
    public let orderKey: String?
    public let organisationName: String?
    public let askToChange: Bool?
    public let webAuthnExtensions: WebAuthnExtensions?
    public var sessionID: String?
    public var accounts: [BulkAccount]?
    public var userHandle: String?

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
        case webAuthnExtensions = "we"
        case userHandle = "h"
    }
}
