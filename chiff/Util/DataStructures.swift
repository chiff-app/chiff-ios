//
//  DataStructures.swift
//  chiff
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
struct BulkAccount: Codable {
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

/// The account object that is shared with the session.
struct SessionAccount: Codable {
    let id: String
    let askToLogin: Bool?
    let askToChange: Bool?
    let username: String
    let sites: [SessionSite]
    let hasPassword: Bool
    let rpId: String?
    let sharedAccount: Bool

    init(account: Account) {
        self.id = account.id
        self.askToLogin = account.askToLogin
        self.askToChange = account.askToChange
        self.username = account.username
        self.sites = account.sites.map({ SessionSite(site: $0) })
        self.rpId = (account as? UserAccount)?.webAuthn?.id
        self.hasPassword = account.hasPassword
        self.sharedAccount = account is SharedAccount
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
struct BackupSharedAccount: Codable, Equatable {
    let id: String
    var username: String
    var sites: [Site]
    var passwordIndex: Int
    var passwordOffset: [Int]?
    var tokenURL: URL?
    var tokenSecret: Data?
    let version: Int
    var notes: String?
}

/// The response sent back to the sessin when a request is received.
struct KeynCredentialsResponse: Codable {
    let type: ChiffMessageType
    let browserTab: Int
    var username: String?
    var password: String?
    var signature: String?
    var counter: Int?
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

    enum CodingKeys: String, CodingKey {
        case username = "u"
        case password = "p"
        case signature = "s"
        case counter = "n"
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
    }

}

enum KeyType: UInt64 {
    case passwordSeed, backupSeed, webAuthnSeed
}

enum CodingError: Error {
    case stringEncoding
    case stringDecoding
    case unexpectedData
    case missingData
}

struct KeyPair {
    let pubKey: Data
    let privKey: Data
}

enum KeyIdentifier: String, Codable {
    // Seed
    case password
    case backup
    case master
    case webauthn

    // BackupManager
    case priv
    case pub
    case encryption

    // NotificationManager
    case subscription
    case endpoint

    func identifier(for keychainService: KeychainService) -> String {
        return "\(keychainService.service).\(self.rawValue)"
    }
}

enum TypeError: Error {
    case wrongViewControllerType
    case wrongViewType
}

enum SortingValue: Int {
    case alphabetically
    case mostly
    case recently

    static var all: [SortingValue] {
        return [.alphabetically, .mostly, .recently]
    }

    var text: String {
        switch self {
        case .alphabetically: return "accounts.alphabetically".localized
        case .mostly: return "accounts.mostly".localized
        case .recently: return "accounts.recently".localized
        }
    }
}
