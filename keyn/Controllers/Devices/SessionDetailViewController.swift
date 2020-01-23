//
//  SessionDetailViewController.swift
//  keyn
//
//  Created by Brandon Maldonado Alonso on 22/01/20.
//  Copyright © 2020 keyn. All rights reserved.
//

import UIKit

class SessionDetailViewController: UITableViewController, UITextFieldDelegate {
    var session: Session! {
        didSet {
            sessionDetailHeader = session is TeamSession ? "devices.team_session_detail_header".localized : "devices.session_detail_header".localized
            sessionDetailFooter = session is TeamSession ? "devices.team_session_detail_footer".localized : "devices.session_detail_footer".localized
        }
    }
    var sessionDetailHeader = "devices.session_detail_header".localized
    var sessionDetailFooter = "devices.session_detail_footer".localized
    @IBOutlet weak var iconView: UIImageView!
    @IBOutlet weak var createdLabel: UILabel!
    @IBOutlet weak var createdValueLabel: UILabel!
    @IBOutlet weak var auxiliaryLabel: UILabel!
    @IBOutlet weak var auxiliaryValueLabel: UILabel!
    @IBOutlet weak var sessionNameTextField: UITextField!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0
        tableView.separatorColor = UIColor.primaryTransparant
        sessionNameTextField.delegate = self
        sessionNameTextField.text = session.title
        createdLabel.text = "devices.created".localized
        createdValueLabel.text = session.creationDate.timeAgoSinceNow()
        if let session = session as? TeamSession {
            auxiliaryLabel.text = "devices.team_auxiliary_title".localized
            auxiliaryValueLabel.text = "42"
        } else {
            auxiliaryLabel.text = "devices.auxiliary_title".localized
            auxiliaryValueLabel.text = "laatst nog"
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? sessionDetailHeader : nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section == 1 ? sessionDetailFooter : nil
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard section == 0 else {
             return
        }
        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = UIColor.primaryHalfOpacity
        header.textLabel?.font = UIFont.primaryBold
        header.textLabel?.textAlignment = NSTextAlignment.left
        header.textLabel?.frame = header.frame
        header.textLabel?.text = sessionDetailHeader
    }

    override func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard section == 1 else {
            return
        }
        let footer = view as! UITableViewHeaderFooterView
        footer.textLabel?.textColor = UIColor.textColorHalfOpacity
        footer.textLabel?.font = UIFont.primaryMediumSmall
        footer.textLabel?.textAlignment = NSTextAlignment.left
        footer.textLabel?.frame = footer.frame
        footer.textLabel?.text = sessionDetailFooter
    }

    @IBAction func deleteDevice(_ sender: UIButton) {
        let alert = UIAlertController(title: "\("popups.responses.delete".localized) \(session.title)?", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { action in
            self.performSegue(withIdentifier: "DeleteSession", sender: self)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    

}
