//
//  TeamAccessControlViewController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import PromiseKit
import ChiffCore

enum AccessControlType {
    case user
    case role

    var header: String {
        switch self {
        case .user: return "accounts.team_user_header".localized
        case .role: return "accounts.team_role_header".localized
        }
    }

    var footer: String {
        switch self {
        case .user: return "accounts.team_user_footer".localized
        case .role: return "accounts.team_role_footer".localized
        }
    }
}

class TeamAccessControlViewController: UIViewController, UIScrollViewDelegate {

    @IBOutlet weak var tableViewFooter: UILabel!
    @IBOutlet weak var tableViewHeader: KeynLabel!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var tableView: UITableView!

    var allObjects: [AccessControllable]!
    var selectedObjects: [AccessControllable]!
    var type: AccessControlType!
    weak var delegate: AccessControlDelegate!

    override func viewDidLoad() {
        super.viewDidLoad()

        scrollView.delegate = self
        tableView.delegate = self
        tableView.dataSource = self

        tableViewHeader.text = type.header
        tableViewFooter.text = type.footer
    }

    // MARK: - Table view data source

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        delegate.setObjects(objects: selectedObjects, type: type)
    }

}

extension TeamAccessControlViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return allObjects.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        return tableView.dequeueReusableCell(withIdentifier: "TeamUserCell", for: indexPath)
    }

}

extension TeamAccessControlViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: false)
        let object = allObjects[indexPath.row]
        if selectedObjects.contains(where: { $0.id == object.id }) {
            tableView.cellForRow(at: indexPath)?.accessoryType = .none
            selectedObjects.removeAll(where: { $0.id == object.id })
        } else {
            tableView.cellForRow(at: indexPath)?.accessoryType = .checkmark
            selectedObjects.append(allObjects[indexPath.row])
        }
    }

    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        let object = allObjects[indexPath.row]
        cell.textLabel?.text = object.name
        if selectedObjects.contains(where: { $0.id == object.id }) {
            cell.accessoryType = .checkmark
        }
    }

}
