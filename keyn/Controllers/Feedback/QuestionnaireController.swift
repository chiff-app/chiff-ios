
import UIKit
import JustLog

class QuestionnaireController: UINavigationController {
    var questions: [Question]? = nil
    var index = 0
   
    override func viewDidLoad() {
        super.viewDidLoad()
        guard questions != nil else {
            Logger.shared.warning("No questions found when starting questionnaire.")
            dismiss(animated: true, completion: nil)
            return
        }
        nextQuestion()
    }
    
    func previousQuestion() {
        self.index -= 1
    }
    
    func submitQuestion(index: Int, question: Question?) {
        if let question = question {
           questions![index] = question
        }
    }
    
    func nextQuestion() {
        let storyboard: UIStoryboard = UIStoryboard(name: "Feedback", bundle: nil)
        if index < questions!.count {
            switch questions![index].type {
            case .boolean:
                if let viewController = storyboard.instantiateViewController(withIdentifier: "BooleanQuestion") as? BooleanQuestionViewController {
                    viewController.question = questions![index]
                    viewController.questionIndex = index
                    viewController.isFirst = index == 0
                    pushViewController(viewController, animated: true)
                }
            case .likert:
                if let viewController = storyboard.instantiateViewController(withIdentifier: "LikertQuestion") as? LikertQuestionViewController {
                    viewController.question = questions![index]
                    viewController.questionIndex = index
                    viewController.isFirst = index == 0
                    pushViewController(viewController, animated: true)
                }
            default:
                Logger.shared.warning("Unknown question type.", userInfo: ["questionType": questions![index].type])
            }
            index += 1
        } else {
            if let viewController = storyboard.instantiateViewController(withIdentifier: "FinishQuestionnaire") as? FinishQuestionnaireViewController {
                pushViewController(viewController, animated: true)
            }
        }
    }
    
    func finish() {
        for question in questions! {
            let userInfo: [String: Any] = [
                "type": question.type.rawValue,
                "response": question.response ?? "null"
            ]
            Logger.shared.info(question.text, userInfo: userInfo)
        }
        Question.setTimestamp(date: Date(timeInterval: TimeInterval(3600*24*356*100), since: Date())) // Don't ask for the next 100 years
        dismiss(animated: true, completion: nil)
    }

}
