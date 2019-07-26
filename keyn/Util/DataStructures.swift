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
    let password: String?
    let passwordSuccessfullyChanged: Bool?
    let siteID: String?
    let siteName: String?
    let siteURL: String?
    let type: KeynMessageType
    let username: String?
    let sentTimestamp: TimeInterval
    let count: Int?
    var sessionID: String?
    var accounts: [BulkAccount]?

    enum CodingKeys: String, CodingKey {
        case accountID = "a"
        case browserTab = "b"
        case password = "p"
        case passwordSuccessfullyChanged = "v"
        case sessionID = "i"
        case siteID = "s"
        case siteName = "n"
        case siteURL = "l"
        case type = "r"
        case username = "u"
        case sentTimestamp = "z"
        case count = "x"
        case accounts = "c"
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
    let accounts: AccountList
    let type: KeynMessageType
    let errorLogging: Bool
    let analyticsLogging: Bool
}

/*
 * Keyn account list.
 *
 * Direction: app -> browser
 */
typealias AccountList = [String:JSONAccount]

struct JSONAccount: Codable {
    let askToLogin: Bool?
    let askToChange: Bool?
    let username: String
    let sites: [JSONSite]

    init(account: Account) {
        self.askToLogin = account.askToLogin
        self.askToChange = account.askToChange
        self.username = account.username
        self.sites = account.sites.map({ JSONSite(site: $0) })
    }
}

struct JSONSite: Codable {
    let id: String
    let url: String
    let name: String

    init(site: Site) {
        self.id = site.id
        self.url = site.url
        self.name = site.name
    }
}

struct BackupAccount: Codable {
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
    }

    init(account: Account, tokenURL: URL?, tokenSecret: Data?) {
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
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.username = try values.decode(String.self, forKey: .username)
        self.sites = try values.decode([Site].self, forKey: .sites)
        self.passwordIndex = try values.decode(Int.self, forKey: .passwordIndex)
        self.lastPasswordUpdateTryIndex = try values.decode(Int.self, forKey: .lastPasswordUpdateTryIndex)
        self.passwordOffset = try values.decode([Int].self, forKey: .passwordOffset)
        self.askToLogin = try values.decodeIfPresent(Bool.self, forKey: .askToLogin)
        self.askToChange = try values.decodeIfPresent(Bool.self, forKey: .askToChange)
        self.enabled = try values.decodeIfPresent(Bool.self, forKey: .enabled) ?? false
        self.tokenURL = try values.decodeIfPresent(URL.self, forKey: .tokenURL)
        self.tokenSecret = try values.decodeIfPresent(Data.self, forKey: .tokenSecret)
    }

}

struct KeynCredentialsResponse: Codable {
    let u: String?          // Username
    let p: String?          // Password
    let np: String?         // New password (for reset only! When registering p will be set)
    let b: Int              // Browser tab id
    let a: String?          // Account id (Only used with changePasswordRequests
    let o: String?          // OTP code
    let t: KeynMessageType  // One of the message types Keyn understands
}

enum KeyType: UInt64 {
    case passwordSeed, backupSeed
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
