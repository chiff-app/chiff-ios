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
    }
    
    func presentQuestionAlert(questionnaire: Questionnaire) {
        let alert = UIAlertController(title: "Questiontime!", message: "Do you have time to answer a few questions? It'll take a moment.", preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Yes!", style: .default, handler: { _ in
            self.launchQuestionnaire(questionnaire: questionnaire)
        }))
        if !questionnaire.compulsory {
            alert.addAction(UIAlertAction(title: "No, thanks", style: .cancel, handler: { _ in
                questionnaire.setFinished()
                questionnaire.save()
                Logger.shared.info("Declined questionnaire.")
            }))
        }
        alert.addAction(UIAlertAction(title: "Remind me later", style: .default, handler: { _ in
            questionnaire.askAgainAt(date: Date(timeInterval: TimeInterval(3600*24), since: Date()))
            questionnaire.save()
            Logger.shared.info("Postponed questionnaire.")
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
