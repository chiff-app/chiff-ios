//
//  DataStructures.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation

/// Used for bulk login actions.
struct BulkLoginAccount: Codable {
    let username: String
    let password: String

    enum CodingKeys: String, CodingKey {
        case username = "u"
        case password = "p"
    }
}

/// Account object when importing from a CSV file.
public struct BulkAccount: Codable {
    let username: String
    let password: String
    let siteId: String
    let siteURL: String
    let siteName: String
    let notes: String?

    enum CodingKeys: String, CodingKey {
        case username = "u"
        case password = "p"
        case siteId = "s"
        case siteName = "n"
        case siteURL = "l"
        case notes = "y"
    }
}

/// Message retrieved from a persistent queue.
struct ChiffPersistentQueueMessage: Codable {
    let passwordSuccessfullyChanged: Bool?
    let accountID: String?
    let type: ChiffMessageType
    let askToLogin: Bool?
    let askToChange: Bool?
    let accounts: [BulkAccount]?
    var receiptHandle: String?

    enum CodingKeys: String, CodingKey {
        case accountID = "a"
        case passwordSuccessfullyChanged = "p"
        case type = "t"
        case receiptHandle = "r"
        case askToLogin = "l"
        case askToChange = "c"
        case accounts = "b"
    }
}

enum SessionObjectType: String, Codable {
    case ssh
    case account
}

protocol SessionObject: Codable {
    var id: String { get }
    var type: SessionObjectType { get set }
}

/// The account object that is shared with the session.
public struct SessionAccount: SessionObject {
    let id: String
    let askToLogin: Bool?
    let askToChange: Bool?
    let username: String
    let sites: [SessionSite]
    let hasPassword: Bool
    let rpId: String? // WebAuthn
    let userHandle: String? // WebAuthn
    let sharedAccount: Bool
    var type: SessionObjectType = .account

    init(account: Account) {
        self.id = account.id
        self.askToLogin = account.askToLogin
        self.askToChange = account.askToChange
        self.username = account.username
        self.sites = account.sites.map({ SessionSite(site: $0) })
        self.rpId = (account as? UserAccount)?.webAuthn?.id
        self.userHandle = (account as? UserAccount)?.webAuthn?.userHandle
        self.hasPassword = account.hasPassword
        self.sharedAccount = account is SharedAccount
    }
}

/// The SSH identity object that is shared with the session.
public struct SSHSessionIdentity: SessionObject {
    let id: String
    let pubKey: String
    let name: String
    let algorithm: SSHAlgorithm
    var type: SessionObjectType = .ssh

    init(identity: SSHIdentity) {
        self.id = identity.id
        self.pubKey = identity.pubKey
        self.name = identity.name
        self.algorithm = identity.algorithm
    }
}


/// The site object that is shared with the session.
struct SessionSite: Codable {
    let id: String
    let url: String
    let name: String

    init(site: Site) {
        self.id = site.id
        self.url = site.url
        self.name = site.name
    }
}

/// The account object that is stored as a backup.
public struct BackupSharedAccount: Codable, Equatable {
    let id: String
    var username: String
    var sites: [Site]
    var passwordIndex: Int
    var passwordOffset: [Int]?
    var tokenURL: URL?
    var tokenSecret: Data?
    let version: Int
    var notes: String?

    public init(id: String, username: String, sites: [Site], passwordIndex: Int, passwordOffset: [Int]? = nil, tokenURL: URL? = nil, tokenSecret: Data? = nil, version: Int, notes: String? = nil) {
        self.id = id
        self.username = username
        self.sites = sites
        self.passwordIndex = passwordIndex
        self.passwordOffset = passwordOffset
        self.tokenURL = tokenURL
        self.tokenSecret = tokenSecret
        self.version = version
        self.notes = notes
    }

}

/// The response sent back to the sessin when a request is received.
struct KeynCredentialsResponse: Codable {
    let type: ChiffMessageType
    let browserTab: Int
    var username: String?
    var password: String?
    var signature: String?
    var algorithm: WebAuthnAlgorithm?
    /// For password change only. When registering `password` should be set.
    var newPassword: String?
    /// Only used with changePasswordRequests
    var accountId: String?
    var otp: String?
    var pubKey: String?
    var accounts: [Int: BulkLoginAccount?]?
    var notes: String?
    var teamId: String?
    var certificates: [String]?
    var error: ChiffErrorResponse?
    var userHandle: String?

    enum CodingKeys: String, CodingKey {
        case username = "u"
        case password = "p"
        case signature = "s"
        case algorithm = "g"
        case newPassword = "np"
        case browserTab = "b"
        case accountId = "a"
        case otp = "o"
        case type = "t"
        case pubKey = "pk"
        case accounts = "d"
        case notes = "y"
        case teamId = "i"
        case certificates = "c"
        case error = "e"
        case userHandle = "h"
    }

}

enum KeyType: UInt64 {
    case passwordSeed, backupSeed, webAuthnSeed, sshSeed
}

public enum CodingError: Error {
    case stringEncoding
    case stringDecoding
    case unexpectedData
    case missingData
}

public struct KeyPair {
    public let pubKey: Data
    public let privKey: Data
}

public enum KeyIdentifier: String, Codable {
    // Seed
    case password
    case backup
    case master
    case webauthn
    case ssh

    // BackupManager
    case priv
    case pub
    case encryption

    // NotificationManager
    case subscription
    case endpoint

    // Attestation
    case attestation

    public func identifier(for keychainService: KeychainService) -> String {
        return "\(keychainService.service).\(self.rawValue)"
    }
}
