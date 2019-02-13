/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class QuestionnaireController: UINavigationController {
    var questionnaire: Questionnaire? = nil
    var index = 0
   
    override func viewDidLoad() {
        super.viewDidLoad()
        guard questionnaire != nil else {
            Logger.shared.warning("No questions found when starting questionnaire.")
            dismiss(animated: true, completion: nil)
            return
        }
        if let vc = visibleViewController as? QuestionnaireIntroductionViewController {
            vc.introduction = questionnaire?.introduction
        }
    }
    
    func previousQuestion() {
        self.index -= 1
    }
    
    func submitQuestion(index: Int, question: Question?) {
        if let question = question {
           questionnaire!.questions[index] = question
        }
    }
    
    func cancel() {
        questionnaire?.askAgainAt(date: Date(timeInterval: TimeInterval(3600*24), since: Date()))
        questionnaire?.save()
        dismiss(animated: true, completion: nil)
    }
    
    func nextQuestion() {
        let storyboard: UIStoryboard = UIStoryboard.get(.feedback)
        if index < questionnaire!.questions.count {
            switch questionnaire!.questions[index].type {
            case .boolean:
                if let viewController = storyboard.instantiateViewController(withIdentifier: "BooleanQuestion") as? BooleanQuestionViewController {
                    viewController.question = questionnaire!.questions[index]
                    viewController.questionIndex = index
                    viewController.isFirst = index == 0
                    pushViewController(viewController, animated: true)
                }
            case .likert:
                if let viewController = storyboard.instantiateViewController(withIdentifier: "LikertQuestion") as? LikertQuestionViewController {
                    viewController.question = questionnaire!.questions[index]
                    viewController.questionIndex = index
                    viewController.isFirst = index == 0
                    pushViewController(viewController, animated: true)
                }
            case .text:
                if let viewController = storyboard.instantiateViewController(withIdentifier: "TextQuestion") as? TextQuestionViewController {
                    viewController.question = questionnaire!.questions[index]
                    viewController.questionIndex = index
                    viewController.isFirst = index == 0
                    pushViewController(viewController, animated: true)
                }
            case .mpc:
                if let viewController = storyboard.instantiateViewController(withIdentifier: "MPCQuestion") as? MPCQuestionViewController {
                    viewController.question = questionnaire!.questions[index]
                    viewController.questionIndex = index
                    viewController.isFirst = index == 0
                    pushViewController(viewController, animated: true)
                }
            }
            index += 1
        } else {
            if let viewController = storyboard.instantiateViewController(withIdentifier: "FinishQuestionnaire") as? FinishQuestionnaireViewController {
                pushViewController(viewController, animated: true)
            }
        }
    }
    
    func finish() {
        questionnaire!.submit()
        dismiss(animated: true, completion: nil)
    }
}
