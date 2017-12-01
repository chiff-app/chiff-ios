//
//  BrowserInterface.swift
//  athena
//
//  Created by bas on 01/12/2017.
//  Copyright © 2017 athena. All rights reserved.
//

import Foundation
import AWSCore
import AWSCognito
import AWSSQS
import AWSSNS

enum AWSError: Error {
    case queueUrl(error: String?)
}

class AWS {

    static let sharedInstance = AWS()
    private let sqs = AWSSQS.default()


    private init() {}

    func getIdentification() {
        let credentialsProvider = AWSCognitoCredentialsProvider(regionType:.EUCentral1,
                                                                identityPoolId:"eu-central-1:ed666f3c-643e-4410-8ad8-d37b08a24ff6")
        let configuration = AWSServiceConfiguration(region: .EUCentral1, credentialsProvider: credentialsProvider)
        AWSServiceManager.default().defaultServiceConfiguration = configuration
    }


    func getQueueUrl(queueName: String, completionHandler: @escaping (String) -> Void) throws {
        print("URL requested for queue: \(queueName)")
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
                print("Something went wrong...")
            }
        }
    }


    func sendToSqs(message: String, to queueUrl: String) {
        if let sendRequest = AWSSQSSendMessageRequest() {
            sendRequest.queueUrl = queueUrl
            sendRequest.messageBody = message
            sqs.sendMessage(sendRequest, completionHandler: { (result, error) in
                if error != nil {
                    print("\(String(describing: error))")
                } else {
                    print("Message ID: \(String(describing: result?.messageId))")
                }
            })
        }
    }
    
}
