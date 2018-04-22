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
import AWSLambda

enum AWSError: Error {
    case queueUrl(error: String?)
}

class AWS {

    static let sharedInstance = AWS()
    private let sqs = AWSSQS.default()
    private let sns = AWSSNS.default()
    private let lambda = AWSLambdaInvoker.default()
    private let awsService = "io.keyn.aws"
    private let endpointIdentifier = "snsDeviceEndpointArn"
    private let PAIR_TIMEOUT = 1 // 60
    private let LOGIN_TIMEOUT = 1 // 180
    var snsDeviceEndpointArn: String? // TODO: only save identifier here?

    private init() {}
    
    func getPPD(id: Int, completionHandler: @escaping (_ ppd: PPD) -> Void) {
        let jsonObject: [String: Any] = ["id" : id]
        lambda.invokeFunction("getPPD", jsonObject: jsonObject).continueWith(block: {(task:AWSTask<AnyObject>) -> Any? in
            if let error = task.error {
                print("Error: \(error)")
                return nil
            } else if let jsonDict = task.result as? NSDictionary {
                do {
                    let jsonData = try! JSONSerialization.data(withJSONObject: jsonDict, options: JSONSerialization.WritingOptions.prettyPrinted)
                    let ppd = try! JSONDecoder().decode(PPD.self, from: jsonData)
                    completionHandler(ppd)
                } catch {
                    print(error)
                }

            }
            return nil
        })
    }
    
    func createBackupData(pubKey: String, signedMessage: String) {
        let jsonObject: [String: Any] = [
            "pubKey" : pubKey,
            "message": signedMessage
        ]
        lambda.invokeFunction("createBackupData", jsonObject: jsonObject).continueWith(block: {(task:AWSTask<AnyObject>) -> Any? in
            if let error = task.error {
                print("Error: \(error)")
                return nil
            } else if let jsonDict = task.result as? NSDictionary {
                print(jsonDict)
            }
            return nil
        })
    }
    
    func backupAccount(pubKey: String, id: String, message: String) {
        let jsonObject: [String: Any] = [
            "pubKey" : pubKey,
            "message": message,
            "accountId": id
        ]
        lambda.invokeFunction("setBackupData", jsonObject: jsonObject).continueWith(block: {(task:AWSTask<AnyObject>) -> Any? in
            if let error = task.error {
                print("Error: \(error)")
                return nil
            } else if let jsonDict = task.result as? NSDictionary {
                print(jsonDict)
            }
            return nil
        })
    }
    
    func getBackupData(pubKey: String, message: String, completionHandler: @escaping (_ accountData: Dictionary<String,Any>) -> Void) {
        let jsonObject: [String: Any] = [
            "pubKey" : pubKey,
            "message": message
        ]
        lambda.invokeFunction("getBackupData", jsonObject: jsonObject).continueWith(block: {(task:AWSTask<AnyObject>) -> Any? in
            if let error = task.error {
                print("Error: \(error)")
                return nil
            } else if let jsonDict = task.result as? Dictionary<String,Any> {
                completionHandler(jsonDict)
            }
            return nil
        })
    }

    func sendToSqs(message: String, to queueName: String, sessionID: String, type: BrowserMessageType) {
        if let sendRequest = AWSSQSSendMessageRequest() {
            let queueUrl = "\(Properties.AWSSQSBaseUrl)\(queueName)"
            sendRequest.queueUrl = queueUrl
            sendRequest.messageBody = message
            let typeAttributeValue = AWSSQSMessageAttributeValue()
            typeAttributeValue?.stringValue = String(type.rawValue)
            typeAttributeValue?.dataType = "Number"
            sendRequest.messageAttributes = [ "type": typeAttributeValue! ]
            sqs.sendMessage(sendRequest, completionHandler: { (result, error) in
                if let error = error {
                    print("Error sending message to SQS queue: \(String(describing: error))")
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
                // TODO: Crash for now (with saving, not deleting)
                do {
                    // Try to remove anything from Keychain to avoid conflicts
                    try? Keychain.sharedInstance.delete(id: self.endpointIdentifier, service: self.awsService)
                    try! Keychain.sharedInstance.save(secretData: endpointData, id: self.endpointIdentifier, service: self.awsService)
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
