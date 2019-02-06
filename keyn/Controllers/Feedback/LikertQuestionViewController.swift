/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class LikertQuestionViewController: QuestionViewController {
    @IBOutlet weak var likertValue: ExtendedUISegmentedControl!
    @IBOutlet weak var minLabel: UILabel!
    @IBOutlet weak var maxLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let font = UIFont.systemFont(ofSize: 20)
        likertValue.setTitleTextAttributes([NSAttributedStringKey.font: font], for: .normal)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let responseString = question?.response, let response = Int(responseString) {
            likertValue.selectedSegmentIndex = response - 1
        }
        if let minText = question?.minLabel {
            minLabel.text = minText
        }
        if let maxText = question?.maxLabel {
            maxLabel.text = maxText
        }
    }

    // MARK: - Actions

    @IBAction func likertValue(_ sender: ExtendedUISegmentedControl) {
        question?.response = String(sender.selectedSegmentIndex+1)
        if let navCon = self.navigationController as? QuestionnaireController {
            navCon.submitQuestion(index: questionIndex, question: question)
            navCon.nextQuestion()
        }
    }
}

class ExtendedUISegmentedControl: UISegmentedControl {
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        self.selectedSegmentIndex = UISegmentedControlNoSegment
    }
}
