/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import Foundation
import PromiseKit

enum QuestionType: String, Codable {
    case likert = "likert"
    case boolean = "boolean"
    case text = "text"
    case mpc = "mpc"
}

struct Question: Codable {
    let id: String
    let type: QuestionType
    let text: String
    var response: String?
    let minLabel: String?
    let maxLabel: String?
    let mpcOptions: [String]?

    enum CodingKeys: CodingKey {
        case id
        case type
        case text
        case response
        case minLabel
        case maxLabel
        case mpcOptions
    }

    init(id: String, type: QuestionType, text: String, response: String? = nil, minLabel: String? = nil, maxLabel: String? = nil, mpcOptions: [String]? = nil) {
        self.id = id
        self.type = type
        self.text = text
        self.response = response
        self.minLabel = minLabel
        self.maxLabel = maxLabel
        self.mpcOptions = mpcOptions
    }
}

class Questionnaire: Codable {

    static let suite = "keynQuestionnaire"

    let id: String
    let delay: Int
    let introduction: String
    var isFinished: Bool
    var askAgain: Date?
    var questions: [Question]
    let compulsory: Bool

    enum CodingKeys: CodingKey {
        case id
        case delay
        case introduction
        case questions
        case isFinished
        case askAgain
        case compulsory
    }

    init(id: String, introduction: String, questions: [Question]? = nil, delay: Int? = nil, isFinished: Bool = false, compulsory: Bool = false) {
        self.id = id
        self.introduction = introduction
        self.questions = questions ?? [Question]()
        self.isFinished = isFinished
        if let delay = delay {
            self.delay = delay
            self.askAgain = Calendar.current.date(byAdding: .day, value: delay, to: Date())
        } else {
            self.delay = 0
        }
        self.compulsory = compulsory
    }

    required init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try values.decode(String.self, forKey: .id)
        self.introduction = try values.decode(String.self, forKey: .introduction)
        self.isFinished = try values.decodeIfPresent(Bool.self, forKey: .isFinished) ?? false
        if let askAgain = try values.decodeIfPresent(Date.self, forKey: .askAgain) {
            // Decoded from PropertyList
            self.askAgain = askAgain
            self.delay = try values.decode(Int.self, forKey: .delay)
        } else if let delay = try values.decodeIfPresent(Int.self, forKey: .delay) {
            // Decoded from JSON
            self.delay = delay
            self.askAgain = Calendar.current.date(byAdding: .day, value: delay, to: Date())
        } else {
            self.delay = 0
        }
        self.questions = try values.decode([Question].self, forKey: .questions)
        self.compulsory = Properties.environment == .prod ? false : try values.decodeIfPresent(Bool.self, forKey: .compulsory) ?? false // In production, questionnaire are never compulsory
    }

    func askAgainAt(date: Date) {
        askAgain = date
    }

    func shouldAsk() -> Bool {
        guard !isFinished else {
            return false
        }
        if let askAgain = askAgain {
            return Date().timeIntervalSince1970 - askAgain.timeIntervalSince1970 > 0
        } else {
            return true
        }
    }

    func save() {
        do {
            let data = try JSONEncoder().encode(self)
            let filemgr = FileManager.default
            let libraryURL = filemgr.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            let questionnairePath = libraryURL.appendingPathComponent("questionnaires").appendingPathComponent(id).path
            filemgr.createFile(atPath: questionnairePath, contents: data, attributes: nil)
        } catch {
            Logger.shared.warning("Could not write questionnaire", error: error)
        }
    }

    func submit() {
        for question in questions {
            let userInfo: [String: Any] = [
                "message": "Questionnaire response",
                "questionID": question.id,
                "type": question.type.rawValue,
                "response": question.response ?? "null",
                "questionnaire": id,
                "userId": Properties.userId ?? "anonymous"
            ]
            guard let jsonData = try? JSONSerialization.data(withJSONObject: userInfo, options: []) else {
                break
            }
            firstly {
                API.shared.request(path: "questionnaires", method: .post, body: jsonData)
            }.catch { error in
                if let error = error as? APIError, case .noData = error {
                    return
                }
                Logger.shared.warning("Error submitting questionnaire response", error: error, userInfo: nil)
            }
        }
        isFinished = true
        save()
    }

    // MARK: - Static functions

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
            Logger.shared.warning("No questionnaires not found.", error: error)
        }
        return questionnaires
    }

    static func fetch() {
        firstly {
            API.shared.request(path: "questionnaires", method: .get, parameters: nil)
        }.done { result in
            if let questionnaires = result["questionnaires"] as? [Any] {
                for object in questionnaires {
                    do {
                        let jsonData = try JSONSerialization.data(withJSONObject: object, options: [])
                        let questionnaire = try JSONDecoder().decode(Questionnaire.self, from: jsonData)
                        if !exists(id: questionnaire.id) {
                            questionnaire.save()
                        }
                    } catch {
                        Logger.shared.error("Failed to decode questionnaire", error: error)
                    }
                }
            }
        }.catchLog("Could not get questionnaire.")
    }

    static func createQuestionnaireDirectory() {
        let filemgr = FileManager.default
        let libraryURL = filemgr.urls(for: .libraryDirectory, in: .userDomainMask)[0]
        let newDir = libraryURL.appendingPathComponent("questionnaires").path
        do {
            try filemgr.createDirectory(atPath: newDir,
                                        withIntermediateDirectories: true, attributes: nil)
        } catch {
            Logger.shared.error("Error creating questionnaire directory", error: error)
        }
    }

    static private func readFile(path: String) -> Questionnaire? {
        let filemgr = FileManager.default
        guard let data = filemgr.contents(atPath: path) else {
            return nil
        }
        do {
            return try JSONDecoder().decode(Questionnaire.self, from: data)
        } catch {
            Logger.shared.warning("Questionnaire not found.", error: error)
            try? filemgr.removeItem(atPath: path) // Remove legacy questionnaire
        }
        return nil
    }

    // DEBUGGING
    static func cleanFolder() {
        let filemgr = FileManager.default
        let questionnaireDirUrl = filemgr.urls(for: .libraryDirectory, in: .userDomainMask)[0].appendingPathComponent("questionnaires")
        do {
            let filelist = try filemgr.contentsOfDirectory(atPath: questionnaireDirUrl.path)
            for filename in filelist {
                try filemgr.removeItem(atPath: questionnaireDirUrl.appendingPathComponent(filename).path)
            }
        } catch {
            Logger.shared.warning("Could not delete questionnaires", error: error)
        }
    }
}
