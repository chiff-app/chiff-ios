//
//  SessionDetailViewController.swift
//  keyn
//
//  Created by Brandon Maldonado Alonso on 22/01/20.
//  Copyright © 2020 keyn. All rights reserved.
//

import UIKit

let buttonCell = "ButtonCell"

class SessionDetailViewController: UIViewController {
    var session: Session?
    @IBOutlet weak var imageView: UIImageView!
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var createdLabel: UILabel!
    @IBOutlet weak var createdValueLabel: UILabel!
    @IBOutlet weak var auxiliaryLabel: UILabel!
    @IBOutlet weak var auxiliaryValueLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        prepareSubview()
    }

    func prepareSubview() {
        tableView.isScrollEnabled = false
        tableView.separatorColor = UIColor.primaryTransparant
        tableView.allowsSelection = false
        if let session = session {
            imageView.image = session.sessionImage
        }
//
//        sessionDetailView.tableView.dataSource = self
//        sessionDetailView.tableView.delegate = self
//        sessionDetailView.tableView.register(UITableViewCell.self, forCellReuseIdentifier: buttonCell)
//        sessionDetailView.tableView.register(TextFieldTableViewCell.self, forCellReuseIdentifier: TextFieldTableViewCell.identifier)
    }
}

extension SessionDetailViewController: UITableViewDataSource {
    
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 1
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var cell: UITableViewCell
        if (indexPath.section == 1) {
            cell = tableView.dequeueReusableCell(withIdentifier: buttonCell, for: indexPath)
            cell.textLabel?.text = "Prueba"
            cell.textLabel?.textAlignment = .center
            cell.textLabel?.textColor = UIColor.red
        } else {
            guard let textFieldCell = tableView.dequeueReusableCell(withIdentifier: TextFieldTableViewCell.identifier, for: indexPath) as? TextFieldTableViewCell else { fatalError() }
            textFieldCell.label.text = "Name"
            textFieldCell.textField.placeholder = "Name"
            cell = textFieldCell
        }
        return cell
    }
    
    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return section == 0 ? "settings.privacy".localized : nil
    }
    
    func tableView(_ tableView: UITableView, titleForFooterInSection section: Int) -> String? {
        return section == 1 ? "settings.reset_warning".localized : nil
    }
}

extension SessionDetailViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        guard section == 0 else {
            return
        }

        let header = view as! UITableViewHeaderFooterView
        header.textLabel?.textColor = UIColor.primaryHalfOpacity
        header.textLabel?.font = UIFont.primaryBold
        header.textLabel?.textAlignment = NSTextAlignment.left
        header.textLabel?.frame = header.frame
        header.textLabel?.text = "settings.privacy".localized
    }
    
    func tableView(_ tableView: UITableView, willDisplayFooterView view: UIView, forSection section: Int) {
        guard section == 1 else {
            return
        }

        let footer = view as! UITableViewHeaderFooterView
        footer.textLabel?.textColor = UIColor.textColorHalfOpacity
        footer.textLabel?.font = UIFont.primaryMediumSmall
        footer.textLabel?.textAlignment = NSTextAlignment.left
        footer.textLabel?.frame = footer.frame
        footer.textLabel?.text = "settings.reset_warning".localized
    }
}
