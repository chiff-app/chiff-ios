//
//  BrowserInterface.swift
//  athena
//
//  Created by bas on 01/12/2017.
//  Copyright © 2017 athena. All rights reserved.
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
    let snsARN = "TODO:fixARN"


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
