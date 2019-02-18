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
    
    func verbose(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil) {
        logger.verbose(message, error: error?.nsError, userInfo: userInfo)
    }
    
    func debug(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil) {
        logger.debug(message, error: error?.nsError, userInfo: userInfo)
    }
    
    func info(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil) {
        logger.info(message, error: error?.nsError, userInfo: userInfo)
    }
    
    func warning(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil) {
        logger.warning(message, error: error?.nsError, userInfo: userInfo)
    }
    
    func error(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil) {
        logger.error(message, error: error?.nsError, userInfo: userInfo)
    }
    
    func analytics(_ message: String, code: AnalyticsMessage, userInfo providedUserInfo: [String: Any]? = nil, error: Error? = nil) {
        var userInfo = providedUserInfo ?? [String:Any]()
        userInfo["code"] = code.rawValue
        logger.info(message, error: error?.nsError, userInfo: userInfo)
    }
    
}

enum KeynError: Error {
    case stringEncoding
    case stringDecoding
    case unexpectedData
}

extension Error {
    private var KEYN_ERROR_CODE: Int {
        return 42
    }
    var nsError: NSError {
        if self is KeynError {
            return NSError(
                domain: Bundle.main.infoDictionary![kCFBundleNameKey as String] as! String,
                code: KEYN_ERROR_CODE,
                userInfo: ["class": type(of: self), "error_type": "\(self)"])
        } else {
            return self as NSError
        }
    }
}
