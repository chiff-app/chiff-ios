//
//  BrowserInterface.swift
//  keyn
//
//  Created by bas on 01/12/2017.
//  Copyright © 2017 keyn. All rights reserved.
//

import Foundation
import AWSCore
import AWSSQS
import AWSSNS

enum AWSError: Error {
    case queueUrl(error: String?)
}

class AWS {

    static let sharedInstance = AWS()
    private let sqs = AWSSQS.default()
    private let sns = AWSSNS.default()
    private let awsService = "io.keyn.aws"
    private let endpointIdentifier = "snsDeviceEndpointArn"
    private let PAIR_TIMEOUT = 60.0
    private let LOGIN_TIMEOUT = 180.0
    let snsPlatformApplicationArn = "arn:aws:sns:eu-central-1:589716660077:app/APNS_SANDBOX/Keyn"
    var snsDeviceEndpointArn: String? // TODO: only save identifier here?

    private init() {}


    // TODO: Unused --> This was replaced by getting the static URL from Properties. Delete if everything seems to work.
    func getQueueUrl(queueName: String, completionHandler: @escaping (String) -> Void) throws {
        guard let queueUrlRequest = AWSSQSGetQueueUrlRequest() else {
            throw AWSError.queueUrl(error: nil)
        }
        queueUrlRequest.queueName = queueName

        // TODO: This getQueueUrl does not call the handler when request is accepted from Home screen (ACCEPT)?
        sqs.getQueueUrl(queueUrlRequest).continueOnSuccessWith { (task: AWSTask!) -> Any? in
            guard let response = task.result else {
                print("TODO: handle error")
                return nil
            }
            if let queueUrl = response.queueUrl {
                completionHandler(queueUrl)
            }
            return nil
        }.continueWith { (task: AWSTask!) -> Any? in
            if task.error != nil {
                print("GetQueueError: \(String(describing: task.error))")
                // TODO: if this is a AWS.SimpleQueueService.NonExistentQueue error, should we delete the session (if any, and there shouldn't be) or do nothing?
            }
            return nil
        }
    }

    func sendToSqs(message: String, to queueName: String, sessionID: String, type: BrowserMessageType) {
        if let sendRequest = AWSSQSSendMessageRequest() {
            sendRequest.queueUrl = "\(Properties.AWSSQSBaseUrl)\(queueName)"
            sendRequest.messageBody = message
            let typeAttributeValue = AWSSQSMessageAttributeValue()
            typeAttributeValue?.stringValue = String(type.rawValue)
            typeAttributeValue?.dataType = "Number"
            sendRequest.messageAttributes = [ "type": typeAttributeValue! ]
            sqs.sendMessage(sendRequest, completionHandler: { (result, error) in
                if let error = error {
                    print("Error sending message to SQS queue: \(String(describing: error))")
                } else if let messageId = result?.messageId {
                    switch type {
                    case .login, .register, .reset:
                        print("Fire timeout @ 180")
                    case .pair:
                        print("Fire timeout @ 60")
                        //Timer.scheduledTimer(timeInterval: self.PAIR_TIMEOUT, target: AWS.sharedInstance, selector: #selector(AWS.sharedInstance.deleteFromSqs(timer:)), userInfo: messageId, repeats: false)
                    default:
                        // Is the sqs queue message retention period (2 weeks)
                        print("End-session message sent.")
                    }
                }
            })
        }
    }

    func snsRegistration(deviceToken: Data) {
        let token = deviceToken.hexEncodedString()
        if Keychain.sharedInstance.has(id: endpointIdentifier, service: awsService) {
            // Get endpoint from Keychain
            do  {
                let endpointData = try Keychain.sharedInstance.get(id: endpointIdentifier, service: awsService)
                snsDeviceEndpointArn = String(data: endpointData, encoding: .utf8)
                checkIfUpdateIsNeeded(token: token)
            } catch {
                print("Error getting endpoint from Keychain: \(error). Create new endpoint?")
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

    // MARK: Private functions

    private func checkIfUpdateIsNeeded(token: String) {
        guard let endpoint = snsDeviceEndpointArn else {
            // No endpoint found. Should not happen, but recreate?
            createPlatformEndpoint(token: token)
            return
        }
        guard let attributesRequest = AWSSNSGetEndpointAttributesInput() else {
            print("Attributes request could not be created: handle error")
            return
        }
        attributesRequest.endpointArn = endpoint
        sns.getEndpointAttributes(attributesRequest).continueWith(block: { (task: AWSTask!) -> Any? in
            if task.error != nil {
                if let error = task.error as NSError? {
                    if error.code == 6 {
                        self.createPlatformEndpoint(token: token)
                    } else {
                        print("Error: \(error)")
                    }
                }
            } else {
                guard let response = task.result else {
                    print("TODO: handle error")
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
            print("Attributes set request could not be created: handle error")
            return
        }
        attributesRequest.attributes = [
            "Token": token,
            "Enabled": "true"
        ]
        attributesRequest.endpointArn = snsDeviceEndpointArn!
        sns.setEndpointAttributes(attributesRequest).continueWith(block: { (task: AWSTask!) -> Any? in
            if task.error != nil {
                print("Error: \(String(describing: task.error))")
            }
            return nil
        })
    }

    private func createPlatformEndpoint(token: String) {
        guard let request = AWSSNSCreatePlatformEndpointInput() else {
            print("Endpoint could not be created: handle error")
            return
        }
        request.token = token
        request.platformApplicationArn = Properties.isDebug ? Properties.AWSPlaformApplicationArn.sandbox : Properties.AWSPlaformApplicationArn.production
        sns.createPlatformEndpoint(request).continueOnSuccessWith(executor: AWSExecutor.mainThread(), block: { (task: AWSTask!) -> Any? in
            guard let response = task.result else {
                print("TODO: handle error")
                return nil
            }
            if let endpointArn = response.endpointArn, let endpointData = endpointArn.data(using: .utf8) {
                do {
                    // Try to remove anything from Keychain to avoid conflicts
                    try? Keychain.sharedInstance.delete(id: self.endpointIdentifier, service: self.awsService)
                    try Keychain.sharedInstance.save(secretData: endpointData, id: self.endpointIdentifier, service: self.awsService)
                    self.snsDeviceEndpointArn = endpointArn
                    self.checkIfUpdateIsNeeded(token: token)
                } catch {
                    print(error)
                }
            }
            return nil
        }).continueWith(block: { (task: AWSTask!) -> Any? in
            if task.error != nil {
                print("Error: \(String(describing: task.error))")
            }
            return nil
        })
    }
}
