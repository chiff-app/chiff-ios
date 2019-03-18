/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation


/*
 * Keyn messages go app <-> browser
 *
 * They always have a type so the app/browser can determine course of action.
 * There is one struct for requests, there are multiple for responses.
 */
enum KeynMessageType: Int, Codable {
    case pair = 0
    case login = 1
    case register = 2
    case change = 3
    case reset = 4          // Unused
    case add = 5
    case addAndChange = 6   // Unused
    case end = 7
    case confirm = 8
    case fill = 9
    case reject = 10
    case expired = 11
    case preferences = 12
}

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
    var sessionID: String?
    let siteID: String?
    let siteName: String?
    let siteURL: String?
    let type: KeynMessageType
    let username: String?
    let sentTimestamp: TimeInterval

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
    }

    /// This checks if the appropriate variables are set for the type of of this request
    func verifyIntegrity() -> Bool {
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
        switch type {
        case .add:
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
                Logger.shared.error("VerifyIntegrity failed because there is no username.")
                return false
            }
        default:
            return false
        }
        
        return true
    }
}

struct KeynPersistentQueueMessage: Codable {
    let passwordSuccessfullyChanged: Bool?
    let accountID: String?
    let type: KeynMessageType
    let askToLogin: Bool?
    let askToChange: Bool?
    var receiptHandle: String?

    enum CodingKeys: String, CodingKey {
        case accountID = "a"
        case passwordSuccessfullyChanged = "p"
        case type = "t"
        case receiptHandle = "r"
        case askToLogin = "l"
        case askToChange = "c"
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
    let userID: String
    let sandboxed: Bool
    let accounts: AccountList
    let type: KeynMessageType
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
    let sites: [JSONSite]

    init(account: Account) {
        self.askToLogin = account.askToLogin
        self.askToChange = account.askToChange
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
