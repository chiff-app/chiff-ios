//
//  Question.swift
//  keyn
//
//  Created by bas on 18/07/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import Foundation
import JustLog

struct Questionnaire: Codable {
    static let queueName = "KeynQuestionnaireQueue"
    static let suite = "keynQuestionnaire"
    
    let id: String
    var questions: [Question]
    
    init(id: String, questions: [Question]? = nil) {
        self.id = id
        self.questions = questions ?? [Question]()
    }
    
    mutating func add(question: Question) {
        questions.append(question)
    }
    
    func setFinished() {
        UserDefaults(suiteName: Questionnaire.suite)?.set(true, forKey: id)
    }
    
    func isFinished() -> Bool {
        guard let defaults = UserDefaults(suiteName: Questionnaire.suite) else {
            return true
        }
        return defaults.bool(forKey: id)
    }
    
    static func get(completionHandler: @escaping (_ questionnaire: [Questionnaire]) -> Void) {
        AWS.sharedInstance.getFromSqs(from: queueName, shortPolling: true) { (messages, _) in
            var questionnaires = [Questionnaire]()
            for message in messages {
                guard let body = message.body, let jsonData = body.data(using: .utf8) else {
                    Logger.shared.error("Could not parse SQS message body.")
                    return
                }
                do {
                    let questionnaire = try JSONDecoder().decode(Questionnaire.self, from: jsonData)
                    questionnaires.append(questionnaire)
                } catch {
                    Logger.shared.error("Failed to decode Question", error: error as NSError)
                }
            }
            completionHandler(questionnaires)
        }
    }
    
    static func shouldAsk() -> Bool {
        guard let installTimestamp = Properties.installTimestamp() else {
            return false
        }
        guard (Date().timeIntervalSince1970 - installTimestamp.timeIntervalSince1970) / 3600 > 168 else {
            return false
        }
        guard let lastQuestionAskTimestamp = UserDefaults.standard.object(forKey: "lastQuestionAskTimestamp") as? Date else {
            return true
        }
        return (Date().timeIntervalSince1970 - lastQuestionAskTimestamp.timeIntervalSince1970) / 3600 > 24
    }
    
    static func setTimestamp(date: Date) {
        UserDefaults.standard.set(date, forKey: "lastQuestionAskTimestamp")
    }
}

enum QuestionType: String, Codable {
    case likert = "likert"
    case boolean = "boolean"
    case text = "text"
}

struct Question: Codable {
    let id: String
    let type: QuestionType
    let text: String
    var response: String?
    
    init(id: String, type: QuestionType, text: String, response: String? = nil) {
        self.id = id
        self.type = type
        self.text = text
        self.response = response
    }
}
