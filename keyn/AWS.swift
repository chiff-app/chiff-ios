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
        // TODO: Is this the best way to convert Data to AWS-accepted string. If so make String extension
        var token = ""
        for i in 0..<deviceToken.count {
            token = token + String(format: "%02.2hhx", arguments: [deviceToken[i]])
        }
        print("Device token: \(token)")

        // Should this be saved here or in ApplicationDelegate?
        UserDefaults.standard.set(token, forKey: "deviceToken")

        // Check if endpointARN is stored
        // TODO: should this be saved in userDefaults or perhaps Keychain?
        snsDeviceEndpointArn = UserDefaults.standard.string(forKey: "snsEndpointArn")
        print("Endpoint: \(snsDeviceEndpointArn)")
        guard let request = AWSSNSCreatePlatformEndpointInput() else {
            print("TODO: handle error")
            return
        }

        // Create new endpoint if not found in storage
        if snsDeviceEndpointArn == nil {
            createPlatformEndpoint(request: request, token: token)
        }

        // TODO: Check if endpoint needs to be updated

        //    if (while getting the attributes a not-found exception is thrown)
        //    # the platform endpoint was deleted
        //    call create platform endpoint with the latest device token
        //    store the returned platform endpoint ARN
        //    else
        //    if (the device token in the endpoint does not match the latest one) or
        //    (get endpoint attributes shows the endpoint as disabled)
        //    call set endpoint attributes to set the latest device token and then enable the platform endpoint
        //    endif
        //    endif

        // See: https://docs.aws.amazon.com/sns/latest/dg/mobile-platform-endpoint.html

    }

    // MARK: Private functions

    private func createPlatformEndpoint(request: AWSSNSCreatePlatformEndpointInput, token: String) {
        request.token = token
        request.platformApplicationArn = snsPlatformApplicationArn
        sns.createPlatformEndpoint(request).continueWith(executor: AWSExecutor.mainThread(), block: { (task: AWSTask!) -> Any? in
            if task.error != nil {
                print("Error: \(String(describing: task.error))")
            } else {
                guard let response = task.result else {
                    print("TODO: handle error")
                    return nil
                }
                if let endpointArn = response.endpointArn {
                    print("endpointArn: \(endpointArn)")
                    self.snsDeviceEndpointArn = endpointArn
                    UserDefaults.standard.set(endpointArn, forKey: "snsEndpointArn")
                }
            }
            return nil
        })
    }
}
