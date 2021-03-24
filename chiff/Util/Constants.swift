//
//  Constants.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import ChiffCore

enum NotificationContentKey: String {
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

enum NotificationType: String {
    case sync = "SYNC"
    case deleteTeamSession = "DELETE_TEAM_SESSION" // Deprecated
    case browser = "BROWSER"
}

enum NotificationCategory {
    static let passwordRequest = "PASSWORD_REQUEST"
    static let endSession = "END_SESSION"
    static let changeConfirmation = "CHANGE_CONFIRMATION"
    static let onboardingNudge = "ONBOARDING_NUDGE"
}

extension Properties {

    private static let sortingPreferenceFlag = "sortingPreference"

    /// The token for amplitude.
    static var amplitudeToken: String {
        switch environment {
        case .dev:
            return "a6c7cba5e56ef0084e4b61a930a13c84"
        case .beta:
            return "1d56fb0765c71d09e73b68119cfab32d"
        case .prod:
            return "081d54cf687bdf40799532a854b9a9b6"
        }
    }

    /// The number of seconds after which the pasteboard should be cleared.
    static let pasteboardTimeout = 60.0 // seconds

    /// The sorting preference of the accounts.
    static var sortingPreference: SortingValue {
        get { return SortingValue(rawValue: UserDefaults.standard.integer(forKey: sortingPreferenceFlag)) ?? SortingValue.alphabetically }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: sortingPreferenceFlag) }
    }
    
    /// Notification identifiers nudges.
    static let nudgeNotificationIdentifiers = [
        "io.keyn.keyn.first_nudge",
        "io.keyn.keyn.second_nudge",
        "io.keyn.keyn.third_nudge"
    ]
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

enum TypeError: Error {
    case wrongViewControllerType
    case wrongViewType
}
