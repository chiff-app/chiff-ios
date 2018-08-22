//
//  MPCQuestionViewController.swift
//  keyn
//
//  Created by bas on 25/07/2018.
//  Copyright © 2018 keyn. All rights reserved.
//

import UIKit
import JustLog

class MPCQuestionViewController: QuestionViewController, UITableViewDataSource, UITableViewDelegate {
    @IBOutlet weak var tableView: UITableView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        guard let mpcOptions = question?.mpcOptions else {
            Logger.shared.warning("No options in MPC question")
            return 0
        }
        return mpcOptions.count
    }
    
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let response = question?.mpcOptions?[indexPath.row]
        question?.response = response
        if let navCon = self.navigationController as? QuestionnaireController {
            navCon.submitQuestion(index: questionIndex, question: question)
            navCon.nextQuestion()
        }
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        if let mpcOptions = question?.mpcOptions {
            if let response = question?.response, let index = mpcOptions.index(of: response) {
                if index == indexPath.row {
                    tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
                }
            }
        }
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "QuestionCell", for: indexPath) as? MPCTableViewCell else {
            Logger.shared.warning("TableViewCell has wrong type.")
            return UITableViewCell()
        }
        
        if let mpcOptions = question?.mpcOptions {
            cell.responseLabel.text = mpcOptions[indexPath.row]
            if indexPath.row == 0 {
                cell.layer.addBorder(edge: .top, color: UIColor(rgb: 0xFFB72F), thickness: 1)
            }
        }
        return cell
    }

}
