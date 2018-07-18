
import UIKit

class LikertQuestionViewController: QuestionViewController {
    @IBOutlet weak var likertValue: UISegmentedControl!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        let font = UIFont.systemFont(ofSize: 20)
        likertValue.setTitleTextAttributes([NSAttributedStringKey.font: font],
                                                for: .normal)
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let responseString = question?.response, let response = Int(responseString) {
            likertValue.selectedSegmentIndex = response - 1
        }
    }
    

    @IBAction func likertValue(_ sender: UISegmentedControl) {
        question?.response = String(sender.selectedSegmentIndex+1)
        if let navCon = self.navigationController as? QuestionnaireController {
            navCon.submitQuestion(index: questionIndex, question: question)
            navCon.nextQuestion()
        }
    }

}
