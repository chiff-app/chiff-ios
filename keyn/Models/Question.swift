//
//  Question.swift
//  keyn
//
//  Created by bas on 18/07/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import Foundation

enum QuestionType: String {
    case likert = "likert"
    case boolean = "boolean"
    case text = "text"
}

struct Question {
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
