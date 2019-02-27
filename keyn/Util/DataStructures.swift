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
    case accountList = 11
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
    }
}

struct KeynPersistentQueueMessage: Codable {
    let accounts: AccountList?
    let passwordSuccessfullyChanged: Bool?
    let accountID: String?
    let type: KeynMessageType
    var receiptHandle: String?

    enum CodingKeys: String, CodingKey {
        case accountID = "a"
        case accounts = "c"
        case passwordSuccessfullyChanged = "p"
        case type = "t"
        case receiptHandle = "r"
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
enum AccountList: Codable {
    case string(String)
    case list([AccountList])
    case dictionary([String : AccountList])

    init?(accounts: [Account]) {
        self = AccountList.dictionary(Dictionary(grouping: accounts, by: { $0.site.id }).mapValues { (accounts) -> AccountList in
            return AccountList.dictionary([
                "siteName": AccountList.string(accounts[0].site.name),
                "accountIds": AccountList.list(accounts.map({ AccountList.string($0.id) }))
                ])
        })
    }

    // Should catch other errors than DecodingError.typeMismatch
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([AccountList].self) {
            self = .list(value)
        } else if let value = try? container.decode([String : AccountList].self) {
            self = .dictionary(value)
        } else {
            throw CodingError.unexpectedData
        }
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let string):
            try container.encode(string)
        case .list(let list):
            try container.encode(list)
        case .dictionary(let dictionary):
            try container.encode(dictionary)
        }
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
