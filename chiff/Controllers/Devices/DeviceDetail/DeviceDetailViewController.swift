//
//  DeviceDetailViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import ChiffCore
import UIKit

class DeviceDetailViewController: UITableViewController, UITextFieldDelegate {
    var session: Session! {
        didSet {
            initialViewSetup()
        }
    }

    var sessionDetailFooter = "devices.session_detail_footer".localized
    var sessionResentHeader = "devices.session_resent_header".localized

    @IBOutlet var recentContainer: UIView!
    @IBOutlet var footerView: DeviceSessionFooterView!

    @IBOutlet var headerView: DeviceDetailsHeaderView! {
        didSet {
            guard let session = session else {
                return
            }
            headerView?.session = session
        }
    }

    @IBOutlet var detailsView: DeviceSessionDetailsView! {
        didSet {
            guard let session = session else {
                return
            }
            self.detailsView?.session = session
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        view.addGestureRecognizer(UITapGestureRecognizer(target: view, action: #selector(UIView.endEditing(_:))))

        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(reloadData(notification:)), name: .sessionUpdated, object: nil)
        nc.addObserver(self, selector: #selector(dismiss(notification:)), name: .sessionEnded, object: nil)
        initialViewSetup()
    }

    private func initialViewSetup() {
        tableView.layer.borderColor = UIColor.primaryTransparant.cgColor
        tableView.layer.borderWidth = 1.0
        tableView.separatorColor = UIColor.primaryTransparant

        guard let session = session as? TeamSession else {
            return
        }
        headerView.isHidden = session.isAdmin
        footerView.isHidden = session.isAdmin
        detailsView.isHidden = session.isAdmin
        recentContainer.isHidden = session.isAdmin
    }

    // MARK: - Actions

    @IBAction func deleteDevice(_ sender: UIButton) {
        let alert = UIAlertController(title: "\("popups.responses.delete".localized) \(session.title)?", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "popups.responses.delete".localized, style: .destructive, handler: { _ in
            self.performSegue(withIdentifier: "DeleteSession", sender: self)
        }))
        present(alert, animated: true, completion: nil)
    }

    // MARK: - Private functions

    @objc private func reloadData(notification: Notification) {
        guard let session = notification.userInfo?["session"] as? Session, session.id == self.session.id else {
            return
        }
        headerView.session = session
        detailsView.session = session
        headerView.setAuxiliaryLabel(count: notification.userInfo?["count"] as? Int)

        tableView.reloadData()
    }

    @objc private func dismiss(notification: Notification) {
        guard let sessionID = notification.userInfo?["sessionID"] as? String,
            session.id == sessionID,
            let navCon = navigationController
        else {
            return
        }
        navCon.popViewController(animated: true)
    }
}
