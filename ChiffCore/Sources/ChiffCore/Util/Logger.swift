//
//  Logger.swift
//  ChiffCore
//
//  Copyright: see LICENSE.md
//

import Foundation

public protocol LoggerProtocol {
    /// Set the user id for analytics and error logging.
    /// - Parameter userId: The user id.
    func setUserId(userId: String?)

    /// Enable / disable analytics logging.
    /// - Parameter value: True to enable, false to disable.
    func setAnalyticsLogging(value: Bool)

    /// Enable / disable error logging.
    /// - Parameter value: True to enable, false to disable.
    func setErrorLogging(value: Bool)

    /// Log an error with the warning level.
    /// - Parameters:
    ///   - message: The message
    ///   - error: Optionally, an error object.
    ///   - userInfo: Optionally, additional information
    func warning(_ message: String, error: Error?, userInfo: [String: Any]?, _ file: StaticString, _ function: StaticString, _ line: UInt)

    /// Log an error with the error level.
    /// - Parameters:
    ///   - message: The message
    ///   - error: Optionally, an error object.
    ///   - userInfo: Optionally, additional information
    ///   - override: Override the user preference.
    func error(_ message: String,
               error: Error?,
               userInfo: [String: Any]?,
               override: Bool,
               _ file: StaticString,
               _ function: StaticString,
               _ line: UInt)

    /// Submit an analytics event.
    /// - Parameters:
    ///   - event: The analytics event.
    ///   - properties: Additional properties
    ///   - override: Override the user preference.
    func analytics(_ event: AnalyticsEvent, properties: [AnalyticsEventProperty: Any]?, override: Bool)
    
    func feedback(message: String, name: String?, email: String?)
}

public extension LoggerProtocol {
    func warning(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil, _ file: StaticString = #file, _ function: StaticString = #function, _ line: UInt = #line) {
        return warning(message, error: error, userInfo: userInfo, file, function, line)
    }

    func error(_ message: String,
               error: Error? = nil,
               userInfo: [String: Any]? = nil,
               override: Bool = false,
               _ file: StaticString = #file,
               _ function: StaticString = #function,
               _ line: UInt = #line) {
        return self.error(message, error: error, userInfo: userInfo, override: override, file, function, line)
    }

    func analytics(_ event: AnalyticsEvent, properties: [AnalyticsEventProperty: Any]? = nil, override: Bool = false) {
        return analytics(event, properties: properties, override: override)
    }
}

public struct Logger: LoggerProtocol {

    public static var shared: LoggerProtocol = Logger()

    public func setUserId(userId: String?) {
        print("UserID set to \(userId ?? "no userid")")
    }

    public func setAnalyticsLogging(value: Bool) {
        print("Analytics set to \(value)")
    }

    public func setErrorLogging(value: Bool) {
        print("Analytics set to \(value)")
    }

    public func warning(_ message: String,
                        error: Error? = nil,
                        userInfo: [String: Any]? = nil,
                        _ file: StaticString = #file,
                        _ function: StaticString = #function,
                        _ line: UInt = #line) {
        print("--------- ⚠️ WARNING: \(String(describing: error)). \(message) ---------")
    }

    public func error(_ message: String,
                      error: Error? = nil,
                      userInfo: [String: Any]? = nil,
                      override: Bool = false,
                      _ file: StaticString = #file,
                      _ function: StaticString = #function,
                      _ line: UInt = #line) {
        print("--------- ☠️ ERROR: \(String(describing: error)). \(message) --------- ")
    }

    public func analytics(_ event: AnalyticsEvent, properties: [AnalyticsEventProperty: Any]? = nil, override: Bool = false) {
        print("ℹ️ EVENT: \(event)")
    }
    
    public func feedback(message: String, name: String?, email: String?) {
        print("FEEDBACK: \(message)")
    }

}

struct KeynError: Error {}
