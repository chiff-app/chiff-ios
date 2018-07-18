
import UIKit

class BooleanQuestionViewController: QuestionViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
    
    @IBAction func yesButton(_ sender: UIButton) {
        question?.response = String("yes")
        if let navCon = self.navigationController as? QuestionnaireController {
            navCon.submitQuestion(index: questionIndex, question: question)
            navCon.nextQuestion()
        }
    }
    
    @IBAction func noButton(_ sender: UIButton) {
        question?.response = String("no")
        if let navCon = self.navigationController as? QuestionnaireController {
            navCon.submitQuestion(index: questionIndex, question: question)
            navCon.nextQuestion()
        }
    }

}