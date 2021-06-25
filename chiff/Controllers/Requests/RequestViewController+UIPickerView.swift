//
//  RequestViewController+UIPickerView.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit
import ChiffCore
import PromiseKit

extension RequestViewController: UIPickerViewDelegate, UIPickerViewDataSource {

    func numberOfComponents(in pickerView: UIPickerView) -> Int {
        return 1
    }

    func pickerView(_ pickerView: UIPickerView, numberOfRowsInComponent component: Int) -> Int {
        return teamSessions.count
    }

    func pickerView(_ pickerView: UIPickerView, viewForRow row: Int, forComponent component: Int, reusing view: UIView?) -> UIView {
        let label = UILabel()
        label.font = UIFont(name: "Montserrat-Bold", size: 18)
        label.textColor = UIColor.white
        label.text = teamSessions[row].title
        label.textAlignment = .center
        return label
    }

    func pickerView(_ pickerView: UIPickerView, didSelectRow row: Int, inComponent component: Int) {
        (self.authorizer as? TeamAdminLoginAuthorizer)?.teamSession = teamSessions[row]
    }

}
