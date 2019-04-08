//
//  KeynTableViewController.swift
//  keyn
//
//  Created by Bas Doorn on 22/03/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class KeynNavigationController: UINavigationController {

    private let height: CGFloat = 38
    private let imageBottomMargin: CGFloat = 0
    private let navBarHeight: CGFloat = 44

    let logoImageView = UIImageView(image: UIImage(named: "logo_purple"))

    override func viewDidLoad() {
        super.viewDidLoad()
        logoImageView.contentMode = .scaleAspectFit
        navigationBar.addSubview(logoImageView)
        logoImageView.clipsToBounds = false
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: navigationBar.centerXAnchor),
            logoImageView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -imageBottomMargin),
            logoImageView.heightAnchor.constraint(equalToConstant: height),
        ])
    }
}
