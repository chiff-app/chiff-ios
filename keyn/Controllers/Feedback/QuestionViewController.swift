/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class QuestionViewController: UIViewController {
    @IBOutlet weak var questionLabel: UILabel!
    
    var question: Question? = nil
    var questionIndex: Int = 0
    var isFirst = false

    override func viewDidLoad() {
        super.viewDidLoad()
        questionLabel.text = question?.text
        self.navigationItem.hidesBackButton = isFirst
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if self.isMovingFromParent, let navCon = self.navigationController as? QuestionnaireController {
            navCon.submitQuestion(index: questionIndex, question: question)
            navCon.previousQuestion()
        }
    }

    // MARK: - Actions

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        guard let navCon = self.navigationController as? QuestionnaireController else {
            fatalError("QuestionViewController not contained in navigationController")
        }
        navCon.cancel()
    }
}
