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
        if Questionnaire.shouldAsk() {
            var questionnaire = Questionnaire(id: "veryUniqueIdentifier")
            questionnaire.add(question: Question(id: "LIKE", type: .likert, text: "How much do you like Keyn?"))
            questionnaire.add(question: Question(id: "SAFE", type: .likert, text: "How safe do you feel logging in with Keyn?"))
            questionnaire.add(question: Question(id: "RECOMMEND", type: .boolean, text: "Would you recommend Keyn to a friend?"))
            questionnaire.add(question: Question(id: "FEE_4_OT", type: .boolean, text: "Would you pay a one-time fee of €4 for Keyn?"))
            questionnaire.add(question: Question(id: "FEE_10_Y", type: .boolean, text: "Would you pay a subscription of €10/year for Keyn?"))
            presentQuestionAlert(questionnaire: questionnaire)
        }
        Questionnaire.get { (questionnaires) in
            for questionnaire in questionnaires {
                DispatchQueue.main.async {
                    self.presentQuestionAlert(questionnaire: questionnaire)
                }
            }
        }
    }
    
    func presentQuestionAlert(questionnaire: Questionnaire) {
        let alert = UIAlertController(title: "Questiontime!", message: "Do you have time to answer a few questions? It'll take a moment.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes!", style: .default, handler: { _ in
            self.launchQuestionnaire(questionnaire: questionnaire)
        }))
        alert.addAction(UIAlertAction(title: "No, thanks", style: .cancel, handler: { _ in
            Questionnaire.setTimestamp(date: Date(timeInterval: TimeInterval(3600*24*356*100), since: Date())) // Don't ask for the next 100 years
            Logger.shared.info("Declined questionnaire.")
        }))
        alert.addAction(UIAlertAction(title: "Remind me later", style: .default, handler: { _ in
            Questionnaire.setTimestamp(date: Date())
        }))
        self.present(alert, animated: true, completion: nil)
        
    }    
    
    func launchQuestionnaire(questionnaire: Questionnaire) {
        let storyboard: UIStoryboard = UIStoryboard(name: "Feedback", bundle: nil)
        guard let modalViewController = storyboard.instantiateViewController(withIdentifier: "QuestionnaireController") as? QuestionnaireController else {
            Logger.shared.error("ViewController has wrong type.")
            return
        }
        modalViewController.questionnaire = questionnaire
        modalViewController.modalPresentationStyle = .fullScreen
        self.present(modalViewController, animated: true, completion: nil)
    }

}
