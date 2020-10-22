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
            if let session = session as? TeamSession {
                sessionDetailFooter = session.isAdmin ? "devices.team_session_admin_detail_footer".localized : "devices.team_session_detail_footer".localized
            } else {
                sessionDetailFooter = "devices.session_detail_footer".localized
            }
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
        iconView.image = session.logo ?? UIImage(named: "logo_purple")
        setAuxiliaryLabel(count: nil)
        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
        let nc = NotificationCenter.default
        nc.addObserver(forName: .sessionUpdated, object: nil, queue: OperationQueue.main, using: reloadData)
        nc.addObserver(forName: .sessionEnded, object: nil, queue: OperationQueue.main, using: dismiss)
    }

    override func numberOfSections(in tableView: UITableView) -> Int {
        if let session = session as? TeamSession, session.isAdmin {
            return 1
        } else {
            return 2
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? sessionDetailHeader : nil
    }

    override func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        if let session = session as? TeamSession, session.isAdmin {
            return sessionDetailFooter
        } else {
            return section == 1 ? sessionDetailFooter : nil
        }
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
        guard (session as? TeamSession)?.isAdmin ?? false || section == 1 else {
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
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { _ in
            self.performSegue(withIdentifier: "DeleteSession", sender: self)
        }))
        self.present(alert, animated: true, completion: nil)
    }

    private func reloadData(notification: Notification) {
        guard let session = notification.userInfo?["session"] as? Session, session.id == self.session.id else {
            return
        }
        self.session = session
        setAuxiliaryLabel(count: notification.userInfo?["count"] as? Int)
        self.tableView.reloadData()
    }

    private func setAuxiliaryLabel(count: Int?) {
        if let session = session as? TeamSession {
            auxiliaryLabel.text = "devices.team_auxiliary_title".localized
            auxiliaryValueLabel.text = "\(count ?? session.accountCount)"
        } else if let session = session as? BrowserSession {
            auxiliaryLabel.text = "devices.auxiliary_title".localized
            auxiliaryValueLabel.text = session.lastRequest?.timeAgoSinceNow() ?? "devices.never".localized.capitalizedFirstLetter
        }
    }

    private func dismiss(notification: Notification) {
        guard let sessionID = notification.userInfo?["sessionID"] as? String,
            session.id == sessionID,
            let navCon = navigationController else {
            return
        }
        navCon.popViewController(animated: true)
    }

}
