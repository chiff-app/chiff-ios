//
//  AccountsPickerButton.swift
//  keyn
//
//  Created by Brandon Maldonado Alonso on 18/03/20.
//  Copyright © 2020 keyn. All rights reserved.
//

import UIKit

class AccountsPickerButton: KeynBarButton {
    let picker: UIPickerView = {
        let picker = UIPickerView()
        return picker
    }()

    private let _inputAccessoryToolbar: UIToolbar = {
        let toolBar = UIToolbar()
        toolBar.barStyle = UIBarStyle.default
        toolBar.isTranslucent = true

        toolBar.sizeToFit()

        return toolBar
    }()

    override var inputView: UIView? {
        return picker
    }

    override var inputAccessoryView: UIView? {
        return _inputAccessoryToolbar
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        setUp()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        setUp()
    }

    override var canBecomeFirstResponder: Bool {
        return true
    }

    @objc private func launchPicker() {
        becomeFirstResponder()
    }

    @objc private func doneClick() {
        resignFirstResponder()
    }

    // MARK: - Private functions

    private func setUp() {
        let doneButton = UIBarButtonItem(title: "Done", style: UIBarButtonItem.Style.plain, target: self, action: #selector(doneClick))
        let spaceButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.flexibleSpace, target: nil, action: nil)

        _inputAccessoryToolbar.setItems([ spaceButton, doneButton], animated: false)

        let tapRecognizer = UITapGestureRecognizer(target: self, action: #selector(launchPicker))
        self.addGestureRecognizer(tapRecognizer)
    }
}
