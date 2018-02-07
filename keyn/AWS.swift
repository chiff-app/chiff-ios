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
    let snsPlatformApplicationArn = "arn:aws:sns:eu-central-1:787429400306:app/APNS_SANDBOX/Keyn"
    var snsDeviceEndpointArn: String? // TODO: only save identifier here?

    private init() {}

    func getQueueUrl(queueName: String, completionHandler: @escaping (String) -> Void) throws {
        guard let queueUrlRequest = AWSSQSGetQueueUrlRequest() else {
            throw AWSError.queueUrl(error: nil)
        }
        queueUrlRequest.queueName = queueName
        sqs.getQueueUrl(queueUrlRequest) { (result, error) in
            if error != nil {
                print("\(String(describing: error))")
            } else if let queueUrl = result?.queueUrl {
                completionHandler(queueUrl)
            } else {
                print("AWS did not produce error, still result is empty.")
            }
        }
    }

    func sendToSqs(message: String, to queueUrl: String, sessionID: String, type: String) {
        if let sendRequest = AWSSQSSendMessageRequest() {
            sendRequest.queueUrl = queueUrl
            sendRequest.messageBody = message
            let idAttribute = AWSSQSMessageAttributeValue()
            idAttribute?.stringValue = type
            idAttribute?.dataType = "String"
            sendRequest.messageAttributes = ["type": idAttribute!]
            sqs.sendMessage(sendRequest, completionHandler: { (result, error) in
                if error != nil {
                    print("\(String(describing: error))")
                } else {
                    print("Message ID: \(String(describing: result?.messageId))")
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
                print("Error: \(String(describing: task.error))")
                // If there's a 'not found exception' here, endpoint should be recreated
                // createPlatformEndpoint(token: token)
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
        request.platformApplicationArn = snsPlatformApplicationArn
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
