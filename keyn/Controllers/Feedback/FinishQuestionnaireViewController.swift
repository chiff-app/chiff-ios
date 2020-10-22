/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class FinishQuestionnaireViewController: UIViewController {
    // MARK: - Actions

    @IBAction func finish(_ sender: UIButton) {
        if let navCon = self.navigationController as? QuestionnaireController {
            navCon.finish()
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        if let navCon = self.navigationController as? QuestionnaireController {
            navCon.cancel()
        }
    }
}
