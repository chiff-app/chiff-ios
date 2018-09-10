//
//  BrowserInterface.swift
//  keyn
//
//  Created by bas on 01/12/2017.
//  Copyright © 2017 keyn. All rights reserved.
//

import Foundation
import AWSCore
import AWSSNS
import JustLog

enum AWSError: Error {
    case queueUrl(error: String?)
    case decodingError
    case createObjectError(error: String?)
}

class AWS {

    static let sharedInstance = AWS()
    private let sns = AWSSNS.default()
    private let awsService = "io.keyn.aws"
    private let endpointKeychainIdentifier = "snsDeviceEndpointArn"
    private let subscriptionKeychainIdentifier = "snsSubscriptionArn"
    private let PAIR_TIMEOUT = 1 // 60
    private let LOGIN_TIMEOUT = 1 // 180
    var snsDeviceEndpointArn: String? // TODO: only save identifier here?
    var isFirstLaunch = false

    private init() {}    
    
    func getIdentityId() -> String {
        if let credentialsProvider = AWSServiceManager.default().defaultServiceConfiguration.credentialsProvider as? AWSCognitoCredentialsProvider {
            return credentialsProvider.identityId ?? "NoIdentityId"
        }
        return "NoIdentityId"
    }

    func snsRegistration(deviceToken: Data) {
        let token = deviceToken.hexEncodedString()
        if Keychain.sharedInstance.has(id: endpointKeychainIdentifier, service: awsService) {
            // Get endpoint from Keychain
            do  {
                let endpointData = try Keychain.sharedInstance.get(id: endpointKeychainIdentifier, service: awsService)
                snsDeviceEndpointArn = String(data: endpointData, encoding: .utf8)
                checkIfUpdateIsNeeded(token: token)
            } catch {
                Logger.shared.warning("Error getting endpoint from Keychain. Creating new endpoint", error: error as NSError)
                // Delete from Keychain
                createPlatformEndpoint(token: token)
            }
        } else {
            // Create new endpoint if not found in storage
            createPlatformEndpoint(token: token)
        }
    }

    func deleteEndpointArn() {
        Keychain.sharedInstance.deleteAll(service: awsService)
    }
    
    func subscribe() {
        guard let subscribeRequest = AWSSNSSubscribeInput() else {
            Logger.shared.error("Could not create subscribeRequest.")
            return
        }
        guard let endpoint = snsDeviceEndpointArn else {
            Logger.shared.error("Could not subscribe. No endpoint.")
            return
        }
        subscribeRequest.protocols = "application"
        subscribeRequest.endpoint = endpoint
        subscribeRequest.topicArn = Properties.isDebug ? Properties.AWSSNSNotificationArn.sandbox : Properties.AWSSNSNotificationArn.production
        sns.subscribe(subscribeRequest).continueOnSuccessWith { (task) -> Any? in
            if let result = task.result {
                if let subscriptionArn = result.subscriptionArn, let subscriptionArnData = subscriptionArn.data(using: .utf8) {
                    do {
                        try Keychain.sharedInstance.save(secretData: subscriptionArnData, id: self.subscriptionKeychainIdentifier, service: self.awsService)
                    } catch {
                        Logger.shared.error("Error saving Keyn subscription identifier.", error: error as NSError)
                        try? Keychain.sharedInstance.update(id: self.subscriptionKeychainIdentifier, service: self.awsService, secretData: subscriptionArnData)
                    }
                } else {
                    Logger.shared.error("Error subscribing to Keyn notifications.")
                }
            }
            return nil
        }.continueWith { (task) -> Any? in
            if let error = task.error {
                Logger.shared.error("Error subscribing to Keyn notifications.", error: error as NSError)
            }
            return nil
        }
    }
    
    func unsubscribe() {
        do {
            guard let unsubscribeRequest = AWSSNSUnsubscribeInput() else {
                throw AWSError.createObjectError(error: "Could not create unsubscribeRequest.")
            }
            let subscriptionEndpointData = try Keychain.sharedInstance.get(id: self.subscriptionKeychainIdentifier, service: self.awsService)
            guard let subscriptionEndpoint = String(data: subscriptionEndpointData, encoding: .utf8) else {
                throw AWSError.decodingError
            }
            unsubscribeRequest.subscriptionArn = subscriptionEndpoint
            sns.unsubscribe(unsubscribeRequest).continueOnSuccessWith { (task) -> Any? in
                do {
                   try Keychain.sharedInstance.delete(id: self.subscriptionKeychainIdentifier, service: self.awsService)
                } catch {
                    Logger.shared.warning("Error deleting subscriptionArn from Keychian", error: error as NSError)
                }
                return nil
            }.continueWith { (task) -> Any? in
                if let error = task.error {
                    Logger.shared.error("Error unsubscribing to Keyn notifications.", error: error as NSError)
                }
                return nil
            }
        } catch {
            Logger.shared.error("Error getting subcription endoint from Keychain", error: error as NSError)
        }
    }
    
    func isSubscribed() -> Bool {
        return Keychain.sharedInstance.has(id: self.subscriptionKeychainIdentifier, service: self.awsService)
    }

    // MARK: Private functions

    private func checkIfUpdateIsNeeded(token: String) {
        guard let endpoint = snsDeviceEndpointArn else {
            Logger.shared.warning("No endpoint found. Creating new endpoint")
            createPlatformEndpoint(token: token)
            return
        }
        guard let attributesRequest = AWSSNSGetEndpointAttributesInput() else {
            Logger.shared.error("Could not create AWSSNSGetEndpointAttributesInput.")
            return
        }
        attributesRequest.endpointArn = endpoint
        sns.getEndpointAttributes(attributesRequest).continueWith(block: { (task: AWSTask!) -> Any? in
            if task.error != nil {
                if let error = task.error as NSError? {
                    if error.code == 6 {
                        Logger.shared.warning("No endpoint found. Creating new endpoint", error: error)
                        self.createPlatformEndpoint(token: token)
                    } else {
                        Logger.shared.error("Could not get endpoint attributes", error: error)
                    }
                }
            } else {
                guard let response = task.result else {
                    Logger.shared.error("Result was empty.")
                    return nil
                }
                if response.attributes!["Token"]! != token || response.attributes!["Enabled"]! != "true" {
                    self.updatePlatformEndpoint(token: token)
                }
            }
            return nil
        })
    }

    private func updatePlatformEndpoint(token: String) {
        guard let attributesRequest = AWSSNSSetEndpointAttributesInput() else {
            Logger.shared.error("Could not create AWSSNSSetEndpointAttributesInput.")
            return
        }
        attributesRequest.attributes = [
            "Token": token,
            "Enabled": "true"
        ]
        attributesRequest.endpointArn = snsDeviceEndpointArn!
        sns.setEndpointAttributes(attributesRequest).continueWith(block: { (task: AWSTask!) -> Any? in
            if let error = task.error {
                Logger.shared.error("Could not update AWS Platform Endpoint.", error: error as NSError)
            }
            return nil
        })
    }

    private func createPlatformEndpoint(token: String) {
        guard let request = AWSSNSCreatePlatformEndpointInput() else {
            Logger.shared.error("Could not create AWSSNSCreatePlatformEndpointInput.")
            return
        }
        request.token = token
        request.platformApplicationArn = Properties.isDebug ? Properties.AWSPlaformApplicationArn.sandbox : Properties.AWSPlaformApplicationArn.production
        sns.createPlatformEndpoint(request).continueOnSuccessWith(executor: AWSExecutor.mainThread(), block: { (task: AWSTask!) -> Any? in
            guard let response = task.result else {
                Logger.shared.error("Result was empty.")
                return nil
            }
            if let endpointArn = response.endpointArn, let endpointData = endpointArn.data(using: .utf8) {
                do {
                    // Try to remove anything from Keychain to avoid conflicts
                    try? Keychain.sharedInstance.delete(id: self.endpointKeychainIdentifier, service: self.awsService)
                    try Keychain.sharedInstance.save(secretData: endpointData, id: self.endpointKeychainIdentifier, service: self.awsService)
                    self.snsDeviceEndpointArn = endpointArn
                    self.checkIfUpdateIsNeeded(token: token)
                    if self.isFirstLaunch {
                        self.subscribe()
                    }
                } catch {
                    Logger.shared.error("Could not save endpoint to keychain", error: error as NSError)
                }
            }
            return nil
        }).continueWith(block: { (task: AWSTask!) -> Any? in
            if let error = task.error {
                Logger.shared.error("Could not create platform endpoint.", error: error as NSError)
            }
            return nil
        })
    }
}
