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
import JustLog

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
        guard let request = AWSLambdaInvokerInvocationRequest() else {
            Logger.shared.error("Could not create AWSLambdaInvokerInvocationRequest.")
            return
        }
        
        request.functionName = "getPPD"
        request.payload = ["id" : id]
        lambda.invoke(request).continueOnSuccessWith(block: { (task) -> Any? in
            if let jsonDict = task.result?.payload as? NSDictionary {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: jsonDict, options: JSONSerialization.WritingOptions.prettyPrinted)
                    let ppd = try JSONDecoder().decode(PPD.self, from: jsonData)
                    completionHandler(ppd)
                } catch {
                    Logger.shared.error("Failed to deocde PPD", error: error as NSError)
                }
            }
            return nil
        }).continueWith { (task) -> Any? in
            if let error = task.error {
                 Logger.shared.error("Error getting PPD.", error: error as NSError)
            }
            return nil
        }
    }
    
    func getDevelopmentPPD(id: String, completionHandler: @escaping (_ ppd: PPD) -> Void) {
        guard let request = AWSLambdaInvokerInvocationRequest() else {
            Logger.shared.error("Could not create AWSLambdaInvokerInvocationRequest.")
            return
        }
        request.functionName = "getDevelopmentPPD"
        request.payload = ["id" : id]
        lambda.invoke(request).continueOnSuccessWith(block: { (task) -> Any? in
            if let jsonDict = task.result?.payload as? Dictionary<String, Any>, let ppdItem = jsonDict["ppd"] as? Dictionary<String,Array<NSDictionary>>, let ppd = ppdItem["ppd"] {
                do {
                    let jsonData = try JSONSerialization.data(withJSONObject: ppd[0], options: JSONSerialization.WritingOptions.prettyPrinted)
                    let ppd = try JSONDecoder().decode(PPD.self, from: jsonData)
                    completionHandler(ppd)
                } catch {
                    Logger.shared.error("Failed to deocde PPD", error: error as NSError)
                }
            }
            return nil
        }).continueWith { (task) -> Any? in
            if let error = task.error {
                Logger.shared.error("Error getting development PPD.", error: error as NSError)
            }
            return nil
        }
    }
    
    func getIdentityId() -> String {
        if let credentialsProvider = AWSServiceManager.default().defaultServiceConfiguration.credentialsProvider as? AWSCognitoCredentialsProvider {
            return credentialsProvider.identityId ?? "NoIdentityId"
        }
        return "NoIdentityId"
    }
    
    func createBackupData(pubKey: String, signedMessage: String) {
        guard let request = AWSLambdaInvokerInvocationRequest() else {
            Logger.shared.error("Could not create AWSLambdaInvokerInvocationRequest.")
            return
        }
        request.functionName = "createBackupData"
        request.payload = [
            "pubKey" : pubKey,
            "message": signedMessage
        ]
        lambda.invoke(request).continueWith { (task) -> Any? in
            if let error = task.error {
                Logger.shared.error("Could not create backup data.", error: error as NSError)
            }
            return nil
        }
    }
    
    func backupAccount(pubKey: String, message: String) {
        guard let request = AWSLambdaInvokerInvocationRequest() else {
            Logger.shared.error("Could not create AWSLambdaInvokerInvocationRequest.")
            return
        }
        request.functionName = "setBackupData"
        request.payload = [
            "pubKey" : pubKey,
            "message": message
        ]
        lambda.invoke(request).continueWith { (task) -> Any? in
            if let error = task.error {
                Logger.shared.error("Could not backup account.", error: error as NSError)
            }
            return nil
        }
    }
    
    func getBackupData(pubKey: String, message: String, completionHandler: @escaping (_ accountData: Dictionary<String,Any>) -> Void) {
        guard let request = AWSLambdaInvokerInvocationRequest() else {
            Logger.shared.error("Could not create AWSLambdaInvokerInvocationRequest.")
            return
        }
        request.functionName = "getBackupData"
        request.payload = [
            "pubKey" : pubKey,
            "message": message
        ]
        lambda.invoke(request).continueOnSuccessWith { (task) -> Any? in
            if let jsonDict = task.result?.payload as? Dictionary<String,Any> {
                completionHandler(jsonDict)
            }
            return nil
        }.continueWith { (task) -> Any? in
            if let error = task.error {
                Logger.shared.error("Could not get backup data.", error: error as NSError)
            }
            return nil
        }
    }
    
    func deleteAccountBackupData(pubKey: String, message: String) {
        guard let request = AWSLambdaInvokerInvocationRequest() else {
            Logger.shared.error("Could not create AWSLambdaInvokerInvocationRequest.")
            return
        }
        request.functionName = "deleteAccount"
        request.payload = [
            "pubKey" : pubKey,
            "message": message
        ]
        lambda.invoke(request).continueWith { (task) -> Any? in
            if let error = task.error {
                Logger.shared.error("Could not delete backup data.", error: error as NSError)
            }
            return nil
        }
    }

    func sendToSqs(message: String, to queueName: String, sessionID: String, type: BrowserMessageType) {
        guard let sendRequest = AWSSQSSendMessageRequest() else {
            Logger.shared.error("Could not create AWSSQSSendMessageRequest.")
            return
        }
        let queueUrl = "\(Properties.AWSSQSBaseUrl)\(queueName)"
        sendRequest.queueUrl = queueUrl
        sendRequest.messageBody = message
        let typeAttributeValue = AWSSQSMessageAttributeValue()
        typeAttributeValue?.stringValue = String(type.rawValue)
        typeAttributeValue?.dataType = "Number"
        sendRequest.messageAttributes = [ "type": typeAttributeValue! ]
        sqs.sendMessage(sendRequest, completionHandler: { (result, error) in
            if let error = error {
                Logger.shared.error("Could not send message to SQS queue.", error: error as NSError)
            }
        })
    }
    
    func deleteFromSqs(receiptHandle: String, queueName: String) {
        guard let deleteRequest = AWSSQSDeleteMessageRequest() else {
            Logger.shared.error("Could not create AWSSQSDeleteMessageRequest.")
            return
        }
        let queueUrl = "\(Properties.AWSSQSBaseUrl)\(queueName)"
        deleteRequest.queueUrl = queueUrl
        deleteRequest.receiptHandle = receiptHandle
        sqs.deleteMessage(deleteRequest).continueWith { (task) -> Any? in
            if let error = task.error {
                Logger.shared.error("Could not delete message to SQS queue.", error: error as NSError)
            }
            return nil
        }
    }
    
    func getFromSqs(from queueName: String, shortPolling: Bool, completionHandler: @escaping (_ messages: [String]) -> Void) {
        guard let receiveRequest = AWSSQSReceiveMessageRequest() else {
            Logger.shared.error("Could not create AWSSQSReceiveMessageRequest.")
            return
        }
        let queueUrl = "\(Properties.AWSSQSBaseUrl)\(queueName)"
        receiveRequest.queueUrl = queueUrl
        receiveRequest.waitTimeSeconds = shortPolling ? 0 : 20
        receiveRequest.messageAttributeNames = ["All"]
        sqs.receiveMessage(receiveRequest).continueOnSuccessWith { (task) -> Any? in
            var returnMessages = [String]()
            if let messages = task.result?.messages {
                for message in messages {
                    guard let body = message.body else {
                        Logger.shared.error("Could not parsw SQS message body.")
                        return nil
                    }
                    guard let receiptHandle = message.receiptHandle else {
                        Logger.shared.error("Could not parsw SQS message body.")
                        return nil
                    }
                    guard let typeString = message.messageAttributes?["type"]?.stringValue, let type = Int(typeString) else {
                        Logger.shared.error("Could not parsw SQS message body.")
                        return nil
                    }
                    if type == BrowserMessageType.confirm.rawValue {
                        returnMessages.append(body)
                        self.deleteFromSqs(receiptHandle: receiptHandle, queueName: queueName)
                    }
                }
            }
            completionHandler(returnMessages)
            return nil
        }.continueWith { (task) -> Any? in
            if let error = task.error {
                Logger.shared.error("Could not get message from SQS queue.", error: error as NSError)
            }
            return nil
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
                    try? Keychain.sharedInstance.delete(id: self.endpointIdentifier, service: self.awsService)
                    try Keychain.sharedInstance.save(secretData: endpointData, id: self.endpointIdentifier, service: self.awsService)
                    self.snsDeviceEndpointArn = endpointArn
                    self.checkIfUpdateIsNeeded(token: token)
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
