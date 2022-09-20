//
//  Constants.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation

public struct ChiffCore {
    /// Initialize the Chiff Core, overriding the logger and localizer. Also syncs clock with NTP.
    /// - Parameters:
    ///   - logger: The logger.
    ///   - localizer: The localizer.
    public static func initialize(logger: LoggerProtocol, localizer: LocalizerProtocol) {
        Logger.shared = logger
        Localizer.shared = localizer
        Date.sync()
    }
}

public enum AnalyticsUserProperty: String {
    case accountCount = "Number of accounts"
    case pairingCount = "Number of pairings"
    case subscribed = "Subscribed"
    case infoNotifications = "Notifications enabled"
    case backupCompleted = "Backup completed"
    case installTime = "Installed on"
    case requestSum = "Request sum"
    case sessionSum = "Session sum" // = Amplitude sessions, as in: times the app was used
}

public enum AnalyticsEvent: String {
    // Onboarding
    case appFirstOpened = "AppFirstOpened"
    case restoreBackupOpened = "RecoverAccountOpened"
    case backupRestored = "BackupRestored"
    case learnMoreClicked = "LearnMoreClicked"
    case seedCreated = "SeedCreated"
    case notificationPermission = "NotificationPermission"
    case cameraPermission = "CameraPermission"
    case tryLaterClicked = "Try later clicked"

    // Requests
    case loginRequestOpened = "LoginRequestOpened"
    case loginRequestAuthorized = "LoginRequestAuthorized"
    case bulkLoginRequestOpened = "BulkLoginRequestOpened"
    case bulkLoginRequestAuthorized = "BulkLoginRequestAuthorized"
    case addSiteRequestOpened = "AddSiteRequestOpened"
    case addSiteRequestAuthorized = "AddSiteRequestAuthorized"
    case addSiteToExistingRequestOpened = "AddSiteToExistingRequestOpened"
    case addSiteToExistingRequestAuthorized = "AddSiteToExistingRequestAuthorized"
    case addBulkSitesRequestOpened = "AddBulkSiteRequestOpened"
    case addBulkSitesRequestAuthorized = "AddBulkSiteRequestAuthorized"
    case changePasswordRequestOpened = "ChangePasswordRequestOpened"
    case changePasswordRequestAuthorized = "ChangePasswordRequestAuthorized"
    case fillPasswordRequestOpened = "FillPasswordRequestOpened"
    case fillPasswordRequestAuthorized = "FillPasswordRequestAuthorized"
    case getDetailsRequestOpened = "GetDetailsRequestOpened"
    case getDetailsRequestAuthorized = "GetDetailsRequestAuthorized"
    case createOrganisationRequestOpened = "CreateOrganisationRequestOpened"
    case createOrganisationRequestAuthorized = "CreateOrganisationRequestAuthorized"
    case adminLoginRequestOpened = "adminLoginRequestOpened"
    case adminLoginRequestAuthorized = "adminLoginRequestAuthorized"
    case webAuthnCreateRequestOpened = "WebAuthnCreateRequestOpened"
    case webAuthnLoginRequestOpened = "WebAuthnLoginRequestOpened"
    case webAuthnCreateRequestAuthorized = "WebAuthnCreateRequestAuthorized"
    case webAuthnLoginRequestAuthorized = "WebAuthnLoginRequestAuthorized"
    case updateAccountRequestOpened = "UpdateAccountRequestOpened"
    case updateAccountRequestAuthorized = "UpdateAccountRequestAuthorized"
    case createSSHKeyRequestOpened = "CreateSSHKeyRequestOpened"
    case createSSHKeyRequestAuthorized = "CreateSSHKeyRequestAuthorized"
    case loginWithSSHRequestOpened = "LoginWithSSHRequestOpened"
    case loginWithSSHRequestAuthorized = "LoginWithSSHRequestAuthorized"

    // Local login
    case passwordCopied = "PasswordCopied"
    case otpCopied = "OneTimePasswordCopied"
    case localLoginOpened = "LocalLoginOpened"
    case localLoginCompleted = "LocalLoginCompleted"

    // Local updates
    case accountUpdated = "AccountUpdated"
    case accountDeleted = "AccountDeleted"
    case accountAddedLocal = "AccountAddedLocal"
    case addAccountOpened = "AddAccountOpened"

    // Backup
    case backupExplanationOpened = "BackupExplanationOpened"
    case backupProcessStarted = "BackupProcessStarted"
    case backupCheckOpened = "BackupCheckOpened"
    case backupCompleted = "BackupCompleted"

    // Devices
    case addSessionOpened = "AddSessionOpened"
    case qrCodeScanned = "QRCodeScanned"
    case paired = "Paired"
    case sessionDeleted = "SessionDeleted"

    // Settings
    case resetKeyn = "ResetKeyn"
    case deleteData = "DeleteData"
    case analytics = "Analytics"
}

/**
 * Keyn messages go app <-> browser
 *
 * They always have a type so the app/browser can determine course of action.
 * There is one struct for requests, there are multiple for responses.
 */
public enum ChiffMessageType: Int, Codable {
    case pair = 0
    case login = 1
    case register = 2
    case change = 3
    case add = 4
    case addBulk = 5
    case addAndLogin = 6 // Can be used for something else in time, does the same as add.
    case end = 7
    case confirm = 8
    case fill = 9
    case reject = 10
    case error = 11
    case preferences = 12
    case addToExisting = 13
    case disabled = 14
    case adminLogin = 15
    case webauthnCreate = 16
    case webauthnLogin = 17
    case bulkLogin = 18
    case getDetails = 19
    case updateAccount = 20
    case createOrganisation = 21
    case addWebauthnToExisting = 22
    case sshCreate = 23
    case sshLogin = 24
}

public enum ChiffErrorResponse: String, Error, Codable {
    case accountExists
    case expired
    case discloseAccountExists
}

public enum AnalyticsEventProperty: String {
    case timestamp = "Timestamp"
    case value = "Value" // True or false
    case scheme = "Scheme" // Of QR-code
    case username = "Username"
    case password = "Password"
    case url = "URL"
    case siteName = "SiteName"
}

enum MessageParameter {
    static let body = "body"
    static let receiptHandle = "receiptHandle"
    static let type = "type"
}

public enum NotificationContentKey: String {
    case browserTab
    case data
    case password
    case sessionID
    case siteID
    case siteName
    case siteURL
    case type
    case username
    case accounts
    case userTeamSessions
    case sessions
}
