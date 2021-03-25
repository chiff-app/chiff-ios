//
//  Properties.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import Foundation
import ChiffCore

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
