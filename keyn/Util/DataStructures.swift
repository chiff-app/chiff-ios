/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

enum NotificationCategory {
    static let PASSWORD_REQUEST = "PASSWORD_REQUEST"
    static let END_SESSION = "END_SESSION"
    static let CHANGE_CONFIRMATION = "CHANGE_CONFIRMATION"
    static let KEYN_NOTIFICATION = "KEYN_NOTIFICATION"
}

enum AnalyticsMessage: String {
    case install = "INSTALL"
    case seedCreated = "SEED_CREATED"
    case update = "UPDATE" // TODO
    case iosUpdate = "IOS_UPDATE" // TODO
    case pairResponse = "PAIR_RESPONSE"
    case loginResponse = "LOGIN_RESPONSE"
    case fillResponse = "FILL_PASSWORD_RESPONSE"
    case addAndChange = "ADDANDCHANGE"
    case passwordChange = "PASSWORD_CHANGE"
    case addResponse = "ADD_RESPONSE"
    case registrationResponse = "REGISTRATION_RESPONSE"
    case sessionEnd = "SESSION_END"
    case deleteAccount = "DELETE_ACCOUNT"
    case backupCompleted = "BACKUP_COMPLETED"
    case keynReset = "KEYN_RESET"
    case passwordCopy = "PASSWORD_COPY"
    case requestDenied = "REQUEST_DENIED"
    case siteReported = "SITE_REPORTED"
    case siteAdded = "SITE_ADDED"
    case accountsRestored = "ACCOUNTS_RESTORED"
    case userFeedback = "USER_FEEDBACK"
    case accountMigration = "ACCOUNT_MIGRATION"
}

// Used by Session
struct PairingResponse: Codable {
    let sessionID: String
    let pubKey: String
    let sns: String
    let userID: String
}

struct BrowserMessage: Codable {
    let s: String?          // PPDHandle
    let r: BrowserMessageType
    let b: Int?          // browserTab
    let n: String?       // Site name
    let v: Bool?         // Value for change password confirmation
    let p: String?       // Old password
    let u: String?       // Possible username
    let a: String?       // AccountID
}

struct CredentialsResponse: Codable {
    let u: String?       // Username
    let p: String?      // Password
    let np: String?     // New password (for reset only! When registering p will be set)
    let b: Int
    let a: String?      // AccountID. Only used with changePasswordRequests
    let o: String?      // OTP code
}

struct PushNotification {
    let sessionID : String
    let siteID: String
    let siteName: String
    let browserTab: Int
    let currentPassword: String?
    let requestType: BrowserMessageType
    let username: String?
}

enum BrowserMessageType: Int, Codable {
    case pair
    case login
    case register
    case change
    case reset
    case add
    case addAndChange
    case end
    case acknowledge
    case fill
}

enum KeyType: UInt64 {
    case passwordSeed, backupSeed
}
