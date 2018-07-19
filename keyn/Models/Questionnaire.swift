//
//  Question.swift
//  keyn
//
//  Created by bas on 18/07/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import Foundation
import JustLog

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

class Questionnaire: Codable {
    static let queueName = "KeynQuestionnaireQueue"
    static let suite = "keynQuestionnaire"
    
    let id: String
    var isFinished: Bool?
    var askAgain: Date?
    var questions: [Question]
    
    init(id: String, questions: [Question]? = nil, isFinished: Bool = false) {
        self.id = id
        self.questions = questions ?? [Question]()
        self.isFinished = isFinished
    }
    
    func add(question: Question) {
        questions.append(question)
    }
    
    func setFinished() {
        isFinished = true
    }
    
    func askAgainAt(date: Date) {
        askAgain = date
    }
    
    func shouldAsk() -> Bool {
        if let isFinished = isFinished {
            guard !isFinished else {
                return false
            }
        }
        guard let askAgain = askAgain else {
            return true
        }
        return Date().timeIntervalSince1970 - askAgain.timeIntervalSince1970 > 0
    }
    
    func save() {
        do {
            let data = try PropertyListEncoder().encode(self)
            let filemgr = FileManager.default
            let libraryURL = filemgr.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            let questionnairePath = libraryURL.appendingPathComponent("questionnaires").appendingPathComponent(id).path
            filemgr.createFile(atPath: questionnairePath, contents: data, attributes: nil)
        } catch {
            Logger.shared.warning("Could not write questionnaire", error: error as NSError)
        }
    }
    
    // MARK: Static functions
    
    static func get(id: String) -> Questionnaire? {
        let filemgr = FileManager.default
        let libraryURL = filemgr.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let questionnairePath = libraryURL.appendingPathComponent("questionnaires").appendingPathComponent(id).path
        return readFile(path: questionnairePath)
    }
    
    static func exists(id: String) -> Bool {
        let filemgr = FileManager.default
        let libraryURL = filemgr.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let questionnairePath = libraryURL.appendingPathComponent("questionnaires").appendingPathComponent(id).path
        return filemgr.fileExists(atPath: questionnairePath)
    }
    
    static func all() -> [Questionnaire] {
        var questionnaires = [Questionnaire]()
        let filemgr = FileManager.default
        let questionnaireDirUrl = filemgr.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("questionnaires")
        do {
            let filelist = try filemgr.contentsOfDirectory(atPath: questionnaireDirUrl.path)
            for filename in filelist {
                if let questionnaire = readFile(path: questionnaireDirUrl.appendingPathComponent(filename).path) {
                    questionnaires.append(questionnaire)
                }
            }
        } catch {
            Logger.shared.warning("No questionnaires not found.", error: error as NSError)
        }
        return questionnaires
    }
    
    static func fetch() {
        AWS.sharedInstance.getFromSqs(from: queueName, shortPolling: true) { (messages, _) in
            for message in messages {
                guard let body = message.body, let jsonData = body.data(using: .utf8) else {
                    Logger.shared.error("Could not parse SQS message body.")
                    return
                }
                do {
                    let questionnaire = try JSONDecoder().decode(Questionnaire.self, from: jsonData)
                    if !exists(id: questionnaire.id) {
                        questionnaire.save()
                    }
                } catch {
                    Logger.shared.error("Failed to decode questionnaire", error: error as NSError)
                }
            }
        }
    }
    
    static private func writeFile(questionnaire: Questionnaire) {
        do {
            let data = try PropertyListEncoder().encode(questionnaire)
            let filemgr = FileManager.default
            let libraryURL = filemgr.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            let questionnairePath = libraryURL.appendingPathComponent("questionnaires").appendingPathComponent(questionnaire.id).path
            filemgr.createFile(atPath: questionnairePath, contents: data, attributes: nil)
        } catch let error as NSError {
            Logger.shared.warning("Could not write questionnaire", error: error)
        }
    }
    
    static private func readFile(path: String) -> Questionnaire? {
        let filemgr = FileManager.default
        guard let data = filemgr.contents(atPath: path) else {
            return nil
        }
        do {
            return try PropertyListDecoder().decode(Questionnaire.self, from: data)
        } catch {
            Logger.shared.warning("Questionnaire not found.", error: error as NSError)
        }
        return nil
    }
    
    static func createQuestionnaireDirectory() {
        let filemgr = FileManager.default
        let libraryURL = filemgr.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let newDir = libraryURL.appendingPathComponent("questionnaires").path
        do {
            try filemgr.createDirectory(atPath: newDir,
                                        withIntermediateDirectories: true, attributes: nil)
        } catch let error as NSError {
            Logger.shared.error("Error creating questionnaire directory", error: error)
        }
    }
}
