/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class RootViewController: UITabBarController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    func presentQuestionAlert(questionnaire: Questionnaire) {
        let alert = UIAlertController(title: "questionnaire_popup_title".localized, message: "questionnaire_permission".localized, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "\("yes".localized.capitalized)!", style: .default, handler: { _ in
            self.launchQuestionnaire(questionnaire: questionnaire)
        }))
        if !questionnaire.compulsory {
            alert.addAction(UIAlertAction(title: "questionnaire_deny".localized, style: .cancel, handler: { _ in
                questionnaire.isFinished = true
                questionnaire.save()
                Logger.shared.analytics("Declined questionnaire.", code: .declinedQuestionnaire)
            }))
        }
        alert.addAction(UIAlertAction(title: "Remind me later", style: .default, handler: { _ in
            questionnaire.askAgainAt(date: Date(timeInterval: TimeInterval.ONE_DAY, since: Date()))
            questionnaire.save()
            Logger.shared.analytics("Postponed questionnaire.", code: .postponedQuestionnaire)
        }))
        self.present(alert, animated: true, completion: nil)
    }    
    
    func launchQuestionnaire(questionnaire: Questionnaire) {
        let storyboard: UIStoryboard = UIStoryboard.get(.feedback)
        guard let modalViewController = storyboard.instantiateViewController(withIdentifier: "QuestionnaireController") as? QuestionnaireController else {
            Logger.shared.error("ViewController has wrong type.")
            return
        }
        modalViewController.questionnaire = questionnaire
        modalViewController.modalPresentationStyle = .fullScreen
        self.present(modalViewController, animated: true, completion: nil)
    }
}
