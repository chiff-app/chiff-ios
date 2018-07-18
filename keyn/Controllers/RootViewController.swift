//
//  RootViewController.swift
//  keyn
//
//  Created by bas on 03/11/2017.
//  Copyright © 2017 keyn. All rights reserved.
//

import UIKit
import JustLog

class RootViewController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.

    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        // Poll queue
        // If messages, present popup.
        
        if Question.shouldAsk() {
            var questions = [Question]()
            questions.append(Question(id: "LIKE", type: .likert, text: "How much do you like Keyn?"))
            questions.append(Question(id: "SAFE", type: .likert, text: "How safe do you feel logging in with Keyn?"))
            questions.append(Question(id: "RECOMMEND", type: .boolean, text: "Would you recommend Keyn to a friend?"))
            questions.append(Question(id: "FEE_4_OT", type: .boolean, text: "Would you pay a one-time fee of €4 for Keyn?"))
            questions.append(Question(id: "FEE_10_Y", type: .boolean, text: "Would you pay a subscription of €10/year for Keyn?"))
            presentQuestionAlert(questions: questions)
        }
    }
    
    func presentQuestionAlert(questions: [Question]) {
        let alert = UIAlertController(title: "Questiontime!", message: "Do you have time to answer a few questions? It'll take a moment.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes!", style: .default, handler: { _ in
            self.launchQuestionnaire(questions: questions)
        }))
        alert.addAction(UIAlertAction(title: "No, thanks", style: .cancel, handler: { _ in
            Question.setTimestamp(date: Date(timeInterval: TimeInterval(3600*24*356*100), since: Date())) // Don't ask for the next 100 years
            Logger.shared.info("Declined questionnaire.")
        }))
        alert.addAction(UIAlertAction(title: "Remind me later", style: .default, handler: { _ in
            Question.setTimestamp(date: Date())
        }))
        self.present(alert, animated: true, completion: nil)
        
    }    
    
    func launchQuestionnaire(questions: [Question]) {
        let storyboard: UIStoryboard = UIStoryboard(name: "Feedback", bundle: nil)
        guard let modalViewController = storyboard.instantiateViewController(withIdentifier: "QuestionnaireController") as? QuestionnaireController else {
            Logger.shared.error("ViewController has wrong type.")
            return
        }
        modalViewController.questions = questions
        modalViewController.modalPresentationStyle = .fullScreen
        self.present(modalViewController, animated: true, completion: nil)
    }

}
