/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

struct BulkAccount: Codable {
    let username: String
    let password: String
    let siteId: String
    let siteURL: String
    let siteName: String

    enum CodingKeys: String, CodingKey {
        case username = "u"
        case password = "p"
        case siteId = "s"
        case siteName = "n"
        case siteURL = "l"
    }
}

struct KeynPersistentQueueMessage: Codable {
    let passwordSuccessfullyChanged: Bool?
    let accountID: String?
    let type: KeynMessageType
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

/*
 * Keyn Responses.
 *
 * Direction: app -> browser
 */
struct KeynPairingResponse: Codable {
    let sessionID: String
    let pubKey: String
    let browserPubKey: String // This is sent back so it is signed together with the app's pubkey
    let userID: String
    let environment: String
    let accounts: [String: SessionAccount]
    let type: KeynMessageType
    let errorLogging: Bool
    let analyticsLogging: Bool
    let version: Int
    let arn: String
}

/*
 * Keyn Responses.
 *
 * Direction: app -> browser
 */
struct KeynTeamPairingResponse: Codable {
    let sessionID: String
    let pubKey: String
    let browserPubKey: String // This is sent back so it is signed together with the app's pubkey
    let userID: String
    let environment: String
    let type: KeynMessageType
    let version: Int
    let arn: String
}

struct SessionAccount: Codable {
    let id: String
    let askToLogin: Bool?
    let askToChange: Bool?
    let username: String
    let sites: [SessionSite]
    let hasPassword: Bool
    let rpId: String?

    init(account: Account) {
        self.id = account.id
        self.askToLogin = account.askToLogin
        self.askToChange = account.askToChange
        self.username = account.username
        self.sites = account.sites.map({ SessionSite(site: $0) })
        self.rpId = (account as? UserAccount)?.webAuthn?.id
        self.hasPassword = account.hasPassword
    }
}

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

struct BackupSharedAccount: Codable {
    let id: String
    var username: String
    var sites: [Site]
    var passwordIndex: Int
    var passwordOffset: [Int]?
    var tokenURL: URL?
    var tokenSecret: Data?
}

struct KeynCredentialsResponse: Codable {
    let u: String?            // Username
    let p: String?            // Password
    let s: String?            // Signagure
    let n: Int?               // Counter
    let g: WebAuthnAlgorithm? // Algorithm COSE identifier
    let np: String?           // New password (for reset only! When registering p will be set)
    let b: Int                // Browser tab id
    let a: String?            // Account id (Only used with changePasswordRequests
    let o: String?            // OTP code
    let t: KeynMessageType    // One of the message types Keyn understands
    let pk: String?           // Webauthn pubkey
}

enum KeyType: UInt64 {
    case passwordSeed, backupSeed, webAuthnSeed
}

enum CodingError: KeynError {
    case stringEncoding
    case stringDecoding
    case unexpectedData
    case missingData
}

struct KeyPair {
    let pubKey: Data
    let privKey: Data
}

// MARK: - StoreKit

struct ProductIdentifiers {
    private let name = "ProductIds"
    private let fileExtension = "plist"

    var isEmpty: String {
        return "\(name).\(fileExtension) is empty. \("storekit.updateResource".localized)"
    }

    var wasNotFound: String {
        return "\("storekit.couldNotFind".localized) \(name).\(fileExtension)."
    }

    /// - returns: An array with the product identifiers to be queried.
    var identifiers: [String]? {
        guard let path = Bundle.main.path(forResource: self.name, ofType: self.fileExtension) else { return nil }
        return NSArray(contentsOfFile: path) as? [String]
    }
}

enum KeyIdentifier: String, Codable {
    // Seed
    case password = "password"
    case backup = "backup"
    case master = "master"
    case webauthn = "webauthn"

    // BackupManager
    case priv = "priv"
    case pub = "pub"
    case encryption = "encryption"

    // NotificationManager
    case subscription = "subscription"
    case endpoint = "endpoint"

    func identifier(for keychainService: KeychainService) -> String {
        return "\(keychainService.rawValue).\(self.rawValue)"
    }
}
