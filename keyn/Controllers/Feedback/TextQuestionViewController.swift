//
//  TextQuestionViewController.swift
//  keyn
//
//  Created by bas on 19/07/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UIKit

class TextQuestionViewController: QuestionViewController {
    @IBOutlet weak var textView: UITextView!
    
    override func viewDidLoad() {
        super.viewDidLoad()

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }

    @IBAction func submit(_ sender: UIButton) {
        question?.response = String(textView.text)
        if let navCon = self.navigationController as? QuestionnaireController {
            navCon.submitQuestion(index: questionIndex, question: question)
            navCon.nextQuestion()
        }
    }

}
