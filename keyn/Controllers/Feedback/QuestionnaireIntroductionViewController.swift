//
//  QuestionnaireIntroductionViewController.swift
//  keyn
//
//  Created by Bas Doorn on 10/09/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UIKit

class QuestionnaireIntroductionViewController: UIViewController {

    var introduction: String!
    @IBOutlet weak var introductionLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        introductionLabel.text = introduction
    }
    
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
