//
//  FinishQuestionnaireViewController.swift
//  keyn
//
//  Created by bas on 18/07/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UIKit

class FinishQuestionnaireViewController: UIViewController {

    @IBAction func finish(_ sender: UIButton) {
        if let navCon = self.navigationController as? QuestionnaireController {
            navCon.finish()
        }
    }

}
