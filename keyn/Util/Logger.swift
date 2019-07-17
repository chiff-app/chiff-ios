//
//  Logger.swift
//  keyn
//
//  Created by Bas Doorn on 11/02/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import Foundation
import JustLog

struct Logger {
    
    static let shared = Logger()
    private let logger = JustLog.Logger()
    
    private init() {
        logger.enableFileLogging = false
        logger.logstashHost = "listener.logz.io"
        logger.logstashPort = 5052
        logger.logzioToken = Properties.logzioToken
        logger.logstashTimeout = 5
        logger.logLogstashSocketActivity = Properties.isDebug
        logger.defaultUserInfo = [
            "app": "Keyn",
            "device": "ios",
            "userID": Properties.userID(),
            "debug": Properties.isDebug]
        logger.setup()
    }
    
    func verbose(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil, _ file: StaticString = #file, _ function: StaticString = #function, _ line: UInt = #line) {
        guard Properties.errorLogging else {
            return
        }
        logger.verbose(message, error: getNSError(error), userInfo: userInfo, file, function, line)
        if let error = error {
            print(error)
        }
    }
    
    func debug(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil, _ file: StaticString = #file, _ function: StaticString = #function, _ line: UInt = #line) {
        guard Properties.errorLogging else {
            return
        }
        logger.debug(message, error: getNSError(error), userInfo: userInfo, file, function, line)
        if let error = error {
            print(error)
        }
    }
    
    func info(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil, _ file: StaticString = #file, _ function: StaticString = #function, _ line: UInt = #line) {
        guard Properties.errorLogging else {
            return
        }
        logger.info(message, error: getNSError(error), userInfo: userInfo, file, function, line)
        if let error = error {
            print(error)
        }
    }
    
    func warning(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil, _ file: StaticString = #file, _ function: StaticString = #function, _ line: UInt = #line) {
        guard Properties.errorLogging else {
            return
        }
        logger.warning(message, error: getNSError(error), userInfo: userInfo, file, function, line)
        if let error = error {
            print(error)
        }
    }
    
    func error(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil, _ file: StaticString = #file, _ function: StaticString = #function, _ line: UInt = #line) {
        guard Properties.errorLogging else {
            return
        }
        logger.error(message, error: getNSError(error), userInfo: userInfo, file, function, line)
        if let error = error {
            print(error)
        }
    }
    
    func analytics(_ message: String, code: AnalyticsMessage, userInfo providedUserInfo: [String: Any]? = nil, error: Error? = nil) {
        guard Properties.analyticsLogging else {
            return
        }
        var userInfo = providedUserInfo ?? [String:Any]()
        userInfo["code"] = code.rawValue
        logger.info(message, error: getNSError(error), userInfo: userInfo)
    }
    
    private func getNSError(_ error: Error?) -> NSError? {
        guard let error = error else {
            return nil
        }
        if let error = error as? KeynError {
            return error.nsError
        } else  {
            print(error as NSError)
            return error as NSError
        }
    }
    
}

protocol KeynError: Error {
    var nsError: NSError { get }
}

extension KeynError {
    private var KEYN_ERROR_CODE: Int {
        return 42
    }
    var nsError: NSError {
        return NSError(
            domain: Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String,
            code: KEYN_ERROR_CODE,
            userInfo: ["class": "\(type(of: self))", "error_type": "\(self)"])
    }
}
