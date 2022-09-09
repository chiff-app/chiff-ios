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
    private static let loginCountFlag = "loginCountFlag"
    private static let hasBeenPromptedReviewFlag = "hasBeenPromptedReviewFlag"
    private static let deniedAutofillFlag = "deniedAutofillFlag"
    private static let autoShowAuthorizationFlag = "autoShowAuthorizationFlag"

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

    static let sentryDsn = "https://6d4ca8274d474708b3f21055a2ce13ef@o1211855.ingest.sentry.io/6729302"

    /// The number of seconds after which the pasteboard should be cleared.
    static let pasteboardTimeout = 29.0 // seconds

    /// The sorting preference of the accounts.
    static var sortingPreference: SortingValue {
        get { return SortingValue(rawValue: UserDefaults.standard.integer(forKey: sortingPreferenceFlag)) ?? SortingValue.alphabetically }
        set { UserDefaults.standard.set(newValue.rawValue, forKey: sortingPreferenceFlag) }
    }

    static var loginCount: Int {
        get { return UserDefaults.standard.integer(forKey: loginCountFlag) }
        set { UserDefaults.standard.set(newValue, forKey: loginCountFlag) }
    }

    static var hasBeenPromptedReview: Bool {
        get { return UserDefaults.standard.string(forKey: hasBeenPromptedReviewFlag) == version }
        set { UserDefaults.standard.setValue(newValue ? version : "", forKey: hasBeenPromptedReviewFlag) }
    }

    static var deniedAutofill: Bool {
        get { return UserDefaults.standard.bool(forKey: deniedAutofillFlag)  }
        set { UserDefaults.standard.setValue(newValue, forKey: deniedAutofillFlag) }
    }

    static var autoShowAuthorization: Bool {
        get { return !hasFaceID || UserDefaults.standard.bool(forKey: autoShowAuthorizationFlag)  }
        set { UserDefaults.standard.setValue(newValue, forKey: autoShowAuthorizationFlag) }
    }

    /// Notification identifiers nudges.
    static let nudgeNotificationIdentifiers = [
        "io.keyn.keyn.first_nudge",
        "io.keyn.keyn.second_nudge",
        "io.keyn.keyn.third_nudge"
    ]
}
