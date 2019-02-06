/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class QuestionnaireIntroductionViewController: UIViewController {

    var introduction: String!
    @IBOutlet weak var introductionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        introductionLabel.text = introduction
    }

    // MARK: - Actions

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        if let navCon = self.navigationController as? QuestionnaireController {
            navCon.cancel()
        }
    }
    
    @IBAction func start(_ sender: UIButton) {
        if let navCon = self.navigationController as? QuestionnaireController {
            navCon.nextQuestion()
        }
    }
}
