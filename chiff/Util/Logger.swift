//
//  Logger.swift
//  keyn
//
//  Created by Bas Doorn on 11/02/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import Foundation
import FirebaseCrashlytics
import Amplitude
import FirebaseCore

struct Logger {

    static let shared = Logger()
    private let crashlytics = Crashlytics.crashlytics()
    private let amplitude = Amplitude.instance()

    private init() {
        FirebaseConfiguration.shared.setLoggerLevel(.min)
        FirebaseApp.configure()
        amplitude.initializeApiKey(Properties.amplitudeToken)
        amplitude.set(userProperties: [
            .accountCount: Properties.accountCount,
            .pairingCount: BrowserSession.count,
            .backupCompleted: Seed.paperBackupCompleted
        ])
        if let userId = Properties.userId {
            setUserId(userId: userId)
        }
        crashlytics.setCustomValue(Properties.environment.rawValue, forKey: "environment")
    }

    func setAnalyticsLogging(value: Bool) {
        if !value {
            // Uploading setting change before opting out.
            analytics(.analytics, properties: [.value: value], override: true)
            uploadAnalytics()
        }
        amplitude.optOut = !value
        if value {
            // Upload setting after opting in.
            analytics(.analytics, properties: [.value: value])
        }
    }

    func setUserId(userId: String?) {
        if let userId = userId {
            crashlytics.setUserID(userId)
            amplitude.setUserId(userId, startNewSession: false)
        }
    }

    func uploadAnalytics() {
        amplitude.uploadEvents()
    }

    func warning(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil, _ file: StaticString = #file, _ function: StaticString = #function, _ line: UInt = #line) {
        #if DEBUG
        print("--------- ⚠️ WARNING: \(String(describing: error)). \(message) ---------")
        #endif
        guard Properties.errorLogging else {
            return
        }
        crashlytics.setCustomValue(message, forKey: "message")
        crashlytics.setCustomValue("warning", forKey: "level")
        crashlytics.setCustomValue(file, forKey: "file")
        crashlytics.setCustomValue(function, forKey: "function")
        crashlytics.setCustomValue(Int32(line), forKey: "line")
        crashlytics.record(error: error ?? KeynError())
    }

    func error(_ message: String,
               error: Error? = nil,
               userInfo: [String: Any]? = nil,
               override: Bool = false,
               _ file: StaticString = #file,
               _ function: StaticString = #function,
               _ line: UInt = #line) {
        #if DEBUG
        print("--------- ☠️ ERROR: \(String(describing: error)). \(message) --------- ")
        #endif
        guard Properties.errorLogging || override else {
            return
        }
        crashlytics.setCustomValue(message, forKey: "message")
        crashlytics.setCustomValue("error", forKey: "level")
        crashlytics.setCustomValue(file, forKey: "file")
        crashlytics.setCustomValue(function, forKey: "function")
        crashlytics.setCustomValue(Int32(line), forKey: "line")
        crashlytics.record(error: error ?? KeynError())
    }

    func analytics(_ event: AnalyticsEvent, properties: [AnalyticsEventProperty: Any]? = nil, override: Bool = false) {
        print("ℹ️ EVENT: \(event)")
        guard Properties.analyticsLogging || override else {
            return
        }
        amplitude.logEvent(event: event, properties: properties)
    }

    func revenue(productId: String, price: NSDecimalNumber) {
        guard Properties.analyticsLogging else {
            return
        }
        let revenue = AMPRevenue()
        revenue.setProductIdentifier(productId)
        revenue.setPrice(price)
        amplitude.logRevenueV2(revenue)
    }

}

struct KeynError: Error {}
