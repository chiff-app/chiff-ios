//
//  DeviceSessionDetailsView.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import ChiffCore
import Foundation
import UIKit

class DeviceSessionDetailsView: UITableViewCell, UITextFieldDelegate {
    var session: Session? {
        didSet {
            viewSetup()
        }
    }
    
    var sessionName: String? {
        sessionNameTextField.text
    }
    
    @IBOutlet private var headerLabel: UILabel!
    @IBOutlet private var sessionNameTextField: UITextField!
    
    private var sessionDetailHeader = "devices.session_detail_header".localized
    
    override func didMoveToWindow() {
        super.didMoveToWindow()
        initialViewSetup()
        viewSetup()
    }
    
    private func initialViewSetup() {
        sessionNameTextField.delegate = self
        headerLabel?.textColor = UIColor.primaryHalfOpacity
        headerLabel?.font = UIFont.primaryBold
        headerLabel?.textAlignment = NSTextAlignment.left
        sessionDetailHeader = session is TeamSession ? "devices.team_session_detail_header".localized : "devices.session_detail_header".localized
        headerLabel.text = sessionDetailHeader
    }
    
    private func viewSetup() {
        sessionNameTextField?.text = session?.title
    }
}
