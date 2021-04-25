//
//  Constants.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import ChiffCore

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

enum Filters: Int {
    case all
    case team
    case personal

    func text() -> String {
        switch self {
        case .all: return "accounts.all".localized
        case .team: return "accounts.team".localized
        case .personal: return "accounts.personal".localized
        }
    }
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
