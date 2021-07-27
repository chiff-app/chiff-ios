//
//  DeviceSessionFooterView.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import ChiffCore
import Foundation
import UIKit

class DeviceSessionFooterView: UITableViewCell, UITextFieldDelegate {
    @IBOutlet private var footerLabel: UILabel!
    @IBOutlet private var recentLabel: UILabel!
    
    private var sessionDetailFooter = "devices.session_detail_footer".localized
    private var sessionResentHeader = "devices.session_resent_header".localized
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        initialViewSetup()
    }
    
    private func initialViewSetup() {
        footerLabel?.textColor = UIColor.textColorHalfOpacity
        footerLabel?.font = UIFont.primaryMediumSmall
        footerLabel?.textAlignment = NSTextAlignment.left
        footerLabel?.text = sessionDetailFooter
        
        recentLabel?.textColor = UIColor.primaryHalfOpacity
        recentLabel?.font = UIFont.primaryBold
        recentLabel?.textAlignment = NSTextAlignment.left

        recentLabel.text = sessionResentHeader
    }
}
