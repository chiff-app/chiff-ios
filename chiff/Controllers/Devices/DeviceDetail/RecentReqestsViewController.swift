//
//  ResentReqestsViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import ChiffCore
import Foundation
import UIKit

class RecentReqestsViewController: UIViewController, UITableViewDataSource {
    var session: Session? {
        didSet {
            tableView?.reloadData()
        }
    }

    @IBOutlet var tableView: UITableView!

    var requests: [ChiffRequestLogModel] {
        guard let session = session, let logs = ChiffRequestsLogStorage.sharedStorage.getLogForSession(ID: session.id) else {
            return [ChiffRequestLogModel]()
        }
        return logs
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "RequestCell")
      }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return requests.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "RequestCell") else {
            return UITableViewCell()
        }
        let request = requests[indexPath.row]
        cell.textLabel?.textColor = UIColor.textColor
        cell.textLabel?.font = UIFont.primaryMediumSmall
        cell.textLabel?.textAlignment = NSTextAlignment.left
        cell.textLabel?.text = "\(request.dateString) \(request.type.logString(param: request.siteName!))" + (request.isRejected ? " (decline)" : "")
        
        return cell
    }
}
