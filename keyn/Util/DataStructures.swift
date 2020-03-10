/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

/*
 * Keyn Requests.
 *
 * Direction: browser -> app
 */
struct KeynRequest: Codable {
    let accountID: String?
    let browserTab: Int?
    let challenge: String?
    let password: String?
    let passwordSuccessfullyChanged: Bool?
    let siteID: String?
    let siteName: String?
    let siteURL: String?
    let type: KeynMessageType
    let relyingPartyId: String?
    let algorithms: [WebAuthnAlgorithm]?
    let username: String?
    let sentTimestamp: TimeInterval
    let count: Int?
    var sessionID: String?
    var accounts: [BulkAccount]?

    enum CodingKeys: String, CodingKey {
        case accountID = "a"
        case browserTab = "b"
        case challenge = "c"
        case password = "p"
        case passwordSuccessfullyChanged = "v"
        case sessionID = "i"
        case siteID = "s"
        case siteName = "n"
        case siteURL = "l"
        case type = "r"
        case algorithms = "g"
        case relyingPartyId = "rp"
        case username = "u"
        case sentTimestamp = "z"
        case count = "x"
        case accounts = "t"
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
        case .webauthnCreate:
            guard relyingPartyId != nil else {
                Logger.shared.error("VerifyIntegrity failed because there is no webauthn relying party ID.")
                return false
            }
            guard let algorithms = algorithms, !algorithms.isEmpty else {
                Logger.shared.error("VerifyIntegrity failed because there is no webauthn algorithm.")
                return false
            }
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

struct BackupTeamAccount: Codable {
    let id: String
    var username: String
    var sites: [Site]
    var passwordIndex: Int
    var passwordOffset: [Int]?
    var tokenURL: URL?
    var tokenSecret: Data?
}

struct TeamRole: Codable {
    let id: String
    let name: String
    let admins: Bool
    var users: [String]

    func encrypt(key: Data) throws -> String {
        let data = try JSONEncoder().encode(self)
        let ciphertext = try Crypto.shared.encryptSymmetric(data, secretKey: key)
        return try Crypto.shared.convertToBase64(from: ciphertext)
    }
}

struct TeamAdminUser: Codable {
    let pubkey: String
    let key: String
    let created: TimeInterval
    let arn: String
    let isAdmin = true
    let name = "Admin"

    func encrypt(key: Data) throws -> String {
        let data = try JSONEncoder().encode(self)
        let ciphertext = try Crypto.shared.encryptSymmetric(data, secretKey: key)
        return try Crypto.shared.convertToBase64(from: ciphertext)
    }
}

struct BackupUserAccount: Codable {
    let id: String
    var username: String
    var sites: [Site]
    var passwordIndex: Int
    var lastPasswordUpdateTryIndex: Int
    var passwordOffset: [Int]?
    var askToLogin: Bool?
    var askToChange: Bool?
    var enabled: Bool
    var tokenURL: URL?
    var tokenSecret: Data?
    var version: Int
    var webAuthn: WebAuthn?

    enum CodingKeys: CodingKey {
        case id
        case username
        case sites
        case passwordIndex
        case lastPasswordUpdateTryIndex
        case passwordOffset
        case askToLogin
        case askToChange
        case enabled
        case tokenURL
        case tokenSecret
        case version
        case webAuthn
    }

    init(account: UserAccount, tokenURL: URL?, tokenSecret: Data?) {
        self.id = account.id
        self.username = account.username
        self.sites = account.sites
        self.passwordIndex = account.passwordIndex
        self.lastPasswordUpdateTryIndex = account.lastPasswordUpdateTryIndex
        self.passwordOffset = account.passwordOffset
        self.askToLogin = account.askToLogin
        self.askToChange = account.askToChange
        self.enabled = account.enabled
        self.tokenURL = tokenURL
        self.tokenSecret = tokenSecret
        self.version = account.version
        self.webAuthn = account.webAuthn
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.username = try values.decode(String.self, forKey: .username)
        self.sites = try values.decode([Site].self, forKey: .sites)
        self.passwordIndex = try values.decode(Int.self, forKey: .passwordIndex)
        self.lastPasswordUpdateTryIndex = try values.decode(Int.self, forKey: .lastPasswordUpdateTryIndex)
        self.passwordOffset = try values.decodeIfPresent([Int].self, forKey: .passwordOffset)
        self.askToLogin = try values.decodeIfPresent(Bool.self, forKey: .askToLogin)
        self.askToChange = try values.decodeIfPresent(Bool.self, forKey: .askToChange)
        self.enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        self.tokenURL = try values.decodeIfPresent(URL.self, forKey: .tokenURL)
        self.tokenSecret = try values.decodeIfPresent(Data.self, forKey: .tokenSecret)
        self.version = try values.decodeIfPresent(Int.self, forKey: .version) ?? 0
        self.webAuthn = try values.decodeIfPresent(WebAuthn.self, forKey: .webAuthn)
    }

}

struct BackupTeamSession: Codable {
    let id: String
    let seed: Data
    let title: String
    let version: Int
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
