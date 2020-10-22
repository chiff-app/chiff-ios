/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class BooleanQuestionViewController: QuestionViewController {
        override func viewDidLoad() {
        super.viewDidLoad()
    }

    // MARK: - Actions

    @IBAction func yesButton(_ sender: UIButton) {
        question?.response = "popups.responses.yes".localized
        if let navCon = self.navigationController as? QuestionnaireController {
            navCon.submitQuestion(index: questionIndex, question: question)
            navCon.nextQuestion()
        }
    }

    @IBAction func noButton(_ sender: UIButton) {
        question?.response = String("popups.responses.no".localized)
        if let navCon = self.navigationController as? QuestionnaireController {
            navCon.submitQuestion(index: questionIndex, question: question)
            navCon.nextQuestion()
        }
    }
}
