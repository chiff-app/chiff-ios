//
//  KeynTableViewController.swift
//  keyn
//
//  Created by Bas Doorn on 22/03/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class KeynTableViewController: UITableViewController {

    private let logoImageView = UIImageView(image: UIImage(named: "logo_purple"))

    override func viewDidLoad() {
        super.viewDidLoad()

        guard let navigationBar = self.navigationController?.navigationBar else { return }
        navigationBar.addSubview(logoImageView)
        logoImageView.clipsToBounds = true
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logoImageView.rightAnchor.constraint(equalTo: navigationBar.rightAnchor, constant: -(navigationBar.frame.width / 2) + (logoImageView.frame.width / 2)),
            logoImageView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -7),
            logoImageView.heightAnchor.constraint(equalToConstant: logoImageView.frame.height),
            logoImageView.widthAnchor.constraint(equalToConstant: logoImageView.frame.width)
        ])
    }

}
