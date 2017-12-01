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

    func getQueueUrl(queueName: String, completionHandler: @escaping (String) -> Void) throws {
        print("URL requested for queue: \(queueName)")
        guard let queueUrlRequest = AWSSQSGetQueueUrlRequest() else {
            throw AWSError.queueUrl(error: nil)
        }
        queueUrlRequest.queueName = queueName
        sqs.getQueueUrl(queueUrlRequest) { (result, error) in
            if error != nil {
                print(error)
            }
            if let queueUrl = result?.queueUrl {
                completionHandler(queueUrl)
            } else {
                print("Something went wrong...")
            }
        }
    }



    private func sendToSqs(message: String, to queueUrl: String) {

        let sqs = AWSSQS.default()

        if let sendRequest = AWSSQSSendMessageRequest() {
            sendRequest.queueUrl = queueUrl
            sendRequest.messageBody = message
            sqs.sendMessage(sendRequest, completionHandler: { (result, error) in
                guard error == nil else {
                    print("Error: \(String(describing: error))")
                    return
                }
                print("Message ID: \(result?.messageId)")
            })
        }
    }
    
}
