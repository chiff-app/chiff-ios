//
//  Questionnaire.swift
//  keynTests
//
//  Created by brandon maldonado alonso on 9/11/19.
//  Copyright © 2019 keyn. All rights reserved.
//

import XCTest

@testable import keyn

class QuestionnaireTests: XCTestCase {
    
    func testAskAgainAtDate() {
        let questionnaire = Questionnaire(id: "1", introduction: "Fake questionnaire", delay: 10)
        let questionnaire2 = Questionnaire(id: "1", introduction: "Fake questionnaire")
        XCTAssertNil(questionnaire2.askAgain)
        XCTAssertNotNil(questionnaire.askAgain)
        questionnaire.askAgainAt(date: Date())
        XCTAssertNotNil(questionnaire.askAgain)
    }
    
    func testShouldAsk() {
        let questionnaire = Questionnaire(id: "1", introduction: "Fake questionnaire", delay: 1)
        XCTAssertFalse(questionnaire.shouldAsk())
        questionnaire.askAgain = nil
        XCTAssertTrue(questionnaire.shouldAsk())
        questionnaire.isFinished = true
        XCTAssertFalse(questionnaire.shouldAsk())
    }
    
    func testSave() {
        let questionnaire = Questionnaire(id: "1", introduction: "Fake questionnaire", delay: 1)
        questionnaire.save()
    }
    
    func testSubmit() {
        API.shared = MockAPI()
        let question = Question(id: "Question 1", type: .boolean, text: "Tesr question")
        let questionnaire = Questionnaire(id: "1", introduction: "Fake questionnaire", questions: [question])
        questionnaire.submit()
    }
    
    func testFetchAndGet() {
        API.shared = MockAPI()
        Questionnaire.fetch()
    }
    
    func testCreateQuestionnaireDirectory() {
        Questionnaire.createQuestionnaireDirectory()
    }
    
    func testGet() {
        XCTAssertNil(Questionnaire.get(id: "thereisnoquestionnaire"))
    }
    
    func testExists() {
        XCTAssertFalse(Questionnaire.exists(id: "thereisnoquestionnaire"))
    }
    
    func testSaveAndAll() {
        let questionnaire = Questionnaire(id: "1", introduction: "Fake questionnaire", delay: 1)
        questionnaire.save()
        XCTAssertFalse(Questionnaire.all().isEmpty)
    }
    
    func testAll() {
        Questionnaire.cleanFolder()
        XCTAssertTrue(Questionnaire.all().isEmpty)
    }

    func testWouter() {
        XCTAssertTrue("wouter".pad(toSize: 200).count == 200, "Having not 199 tests instead of 200 upsets Wouter")
    }
}
