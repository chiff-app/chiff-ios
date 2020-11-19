//
//  PairingResponse.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation

protocol PairingResponse: Encodable {
    var sessionID: String { get }
    var pubKey: String { get }
    var browserPubKey: String { get }
    var userID: String { get }
    var environment: String { get }
    var type: ChiffMessageType { get }
    var version: Int { get }
    var arn: String { get }
}

/*
 * Keyn Responses.
 *
 * Direction: app -> browser
 */
struct BrowserPairingResponse: PairingResponse {
    let sessionID: String
    let pubKey: String
    let browserPubKey: String // This is sent back so it is signed together with the app's pubkey
    let userID: String
    let environment: String
    let type: ChiffMessageType
    let version: Int
    let arn: String
    let accounts: [String: SessionAccount]
    let errorLogging: Bool
    let analyticsLogging: Bool
    let os: String = "ios"
    let appVersion: String?
    let organisationKey: String?
    let organisationType: OrganisationType?
    let isAdmin: Bool?

    init(id: String,
         pubKey: String,
         browserPubKey: String,
         version: Int,
         organisationKey: String?,
         organisationType: OrganisationType?,
         isAdmin: Bool?) throws {
        self.sessionID = id
        self.pubKey = pubKey
        self.browserPubKey = browserPubKey
        self.userID = Properties.userId!
        self.environment = Properties.migrated ? Properties.Environment.prod.rawValue : Properties.environment.rawValue
        self.type = .pair
        self.version = version
        guard let endpoint = Properties.endpoint else {
            throw SessionError.noEndpoint
        }
        self.arn = endpoint
        self.accounts = try UserAccount.combinedSessionAccounts()
        self.errorLogging = Properties.errorLogging
        self.analyticsLogging = Properties.analyticsLogging
        self.appVersion = Properties.version
        self.organisationKey = organisationKey
        self.organisationType = organisationType
        self.isAdmin = isAdmin
    }
}

/*
 * Keyn Responses.
 *
 * Direction: app -> browser
 */
struct TeamPairingResponse: PairingResponse {
    let sessionID: String
    let pubKey: String
    let browserPubKey: String // This is sent back so it is signed together with the app's pubkey
    let userID: String
    let environment: String
    let type: ChiffMessageType
    let version: Int
    let arn: String
    let userPubKey: String

    init(id: String, pubKey: String, browserPubKey: String, version: Int) throws {
        self.sessionID = id
        self.pubKey = pubKey
        self.browserPubKey = browserPubKey
        self.userID = Properties.userId!
        self.environment = Properties.migrated ? Properties.Environment.prod.rawValue : Properties.environment.rawValue
        self.type = .pair
        self.version = version
        self.userPubKey = try Seed.publicKey()
        guard let endpoint = Properties.endpoint else {
            throw SessionError.noEndpoint
        }
        self.arn = endpoint
    }
}
