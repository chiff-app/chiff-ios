/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation

enum AnalyticsUserProperty: String {
    case accountCount = "Account count"
    case pairingCount = "Pairing count"
    case subscribed = "Subscribed"
    case infoNotifications = "Notifications enabled"
    case backupCompleted = "Backup completed"
    case installTime = "Installed on"
    case requestSum = "Request sum"
    case sessionSum = "Session sum" // = Amplitude sessions, as in: times the app was used
}

enum AnalyticsEvent: String {
    // Onboarding
    case appFirstOpened = "AppFirstOpened"
    case restoreBackupOpened = "RecoverAccountOpened"
    case backupRestored = "BackupRestored"
    case learnMoreClicked = "LearnMoreClicked"
    case seedCreated = "SeedCreated"
    case notificationPermission = "NotificationPermission"
    case cameraPermission = "CameraPermission" // TODO
    case tryLaterClicked = "Try later clicked"

    // Requests
    case loginRequestOpened = "LoginRequestOpened"
    case loginRequestAuthorized = "LoginRequestAuthorized"
    case addSiteRequestOpened = "AddSiteRequestOpened"
    case addSiteRequstAuthorized = "AddSiteRequestAuthorized"
    case addSiteToExistingRequestAuthorized = "AddSiteToExistingRequestAuthorized"
    case addBulkSitesRequestOpened = "AddBulkSiteRequestOpened"
    case addBulkSitesRequestAuthorized = "AddBulkSiteRequestAuthorized"
    case changePasswordRequestOpened = "ChangePasswordRequestOpened"
    case changePasswordRequestAuthorized = "ChangePasswordRequestAuthorized"
    case fillPassworddRequestOpened = "FillPassworddRequestOpened"
    case fillPassworddRequestAuthorized = "FillPassworddRequestAuthorized"

    // Local login
    case passwordCopied = "PasswordCopied"
    case otpCopied = "OneTimePasswordCopied"
    case localLogin = "LocalLogin" // TODO

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

    // Questionnaire
    case questionnaireDeclined = "QuestionnaireDeclined"
    case questionnairePostponed = "QuestionnairePostponed"
}

enum AnalyticsEventProperty: String {
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

enum NotificationCategory {
    static let PASSWORD_REQUEST = "PASSWORD_REQUEST"
    static let END_SESSION = "END_SESSION"
    static let CHANGE_CONFIRMATION = "CHANGE_CONFIRMATION"
    static let KEYN_NOTIFICATION = "KEYN_NOTIFICATION"
}

enum NotificationContentKey {
    static let browserTab = "browserTab"
    static let data = "data"
    static let password = "password"
    static let sessionId = "sessionID"
    static let siteId = "siteID"
    static let siteName = "siteName"
    static let siteURL = "siteURL"
    static let type = "type"
    static let username = "username"
}

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
    case add = 4
    case addBulk = 5
    case addAndLogin = 6 // Can be used for something else in time, does the same as add.
    case end = 7
    case confirm = 8
    case fill = 9
    case reject = 10
    case expired = 11
    case preferences = 12
    case addToExisting = 13
}
