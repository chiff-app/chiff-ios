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
    
    @IBOutlet private var auxiliaryLabel: UILabel!
    @IBOutlet private var auxiliaryValueLabel: UILabel!
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        initialSetup()
    }
    
    private func initialSetup() {
        setAuxiliaryLabel(count: nil)
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
    
    func setAuxiliaryLabel(count: Int?) {
        if let session = session as? TeamSession {
            auxiliaryLabel.text = "devices.team_auxiliary_title".localized
            auxiliaryValueLabel.text = "\(count ?? session.accountCount)"
        } else if let session = session as? BrowserSession {
            auxiliaryLabel.text = "devices.auxiliary_title".localized
            auxiliaryValueLabel.text = session.lastRequest?.timeAgoSinceNow() ?? "devices.never".localized.capitalizedFirstLetter
        }
    }
}
