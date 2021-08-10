//
//  DeviceDetailsHeaderView.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import ChiffCore
import Foundation
import UIKit

class DeviceDetailsHeaderView: UIView {
    var session: Session? {
        didSet {
            setupView()
        }
    }

    @IBOutlet private var iconView: UIImageView!

    @IBOutlet private var createdLabel: UILabel!
    @IBOutlet private var createdValueLabel: UILabel!

    override func didMoveToWindow() {
        super.didMoveToWindow()
        setupView()
    }

    private func setupView() {
        createdLabel.text = "devices.created".localized
        guard let session = session else {
            return
        }
        iconView?.image = session.logo ?? UIImage(named: "logo_purple")
        createdValueLabel.text = session.creationDate.timeAgoSinceNow()
    }

}
