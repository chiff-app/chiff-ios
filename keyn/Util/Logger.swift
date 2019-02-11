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
            "device": "APP",
            "userID": Properties.userID(),
            "debug": Properties.isDebug]
        logger.setup()
    }
    
    func verbose(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil) {
        logger.verbose(message, error: makeNSError(error: error), userInfo: userInfo)
    }
    
    func debug(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil) {
        logger.debug(message, error: makeNSError(error: error), userInfo: userInfo)
    }
    
    func info(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil) {
        logger.info(message, error: makeNSError(error: error), userInfo: userInfo)
    }
    
    func warning(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil) {
        logger.warning(message, error: makeNSError(error: error), userInfo: userInfo)
    }
    
    func error(_ message: String, error: Error? = nil, userInfo: [String: Any]? = nil) {
        logger.error(message, error: makeNSError(error: error), userInfo: userInfo)
    }
    
    // MARK: - Private functions
    
    private func makeNSError(error: Error?) -> NSError? {
        guard let error = error else {
            return nil
        }
        switch error {
        case let error as KeynError:
            return error.nsError
        default:
            return error as NSError
        }
    }
    
}

protocol KeynError: Error {
    var nsError: NSError { get }
}
