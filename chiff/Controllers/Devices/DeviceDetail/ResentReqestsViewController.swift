//
//  ResentReqestsViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import ChiffCore
import Foundation
import UIKit

class ResentReqestsViewController: UIViewController, UITableViewDataSource {
    @IBOutlet var tableView: UITableView!

    var sessions = [Session]()

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.register(UITableViewCell.self, forCellReuseIdentifier: "RequestCell")
        do {
            var sessions: [Session] = try BrowserSession.all()
            sessions.append(contentsOf: try TeamSession.all())
            self.sessions = sessions.sorted(by: { $0.creationDate < $1.creationDate })
        } catch {
            Logger.shared.error("Could not get sessions.", error: error)
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }

    // MARK: - UITableViewDataSource

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return sessions.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "RequestCell") else {
            return UITableViewCell()
        }
        cell.textLabel?.text = sessions[indexPath.row].title
        
        return cell
    }
}
