//
//  LocalizableButton.swift
//  keyn
//
//  Created by Bas Doorn on 26/08/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

@IBDesignable class LocalizableBarButton: UIBarButtonItem, XIBLocalizable {

    var originalButtonText: String?
    var activityIndicator: UIActivityIndicatorView!

    @IBInspectable var localizationKey: String? = nil {
        didSet {
            if let key = localizationKey {
                title = key.localized
            }
        }
    }

    func showLoading() {
        originalButtonText = self.title
        self.title = ""
        if activityIndicator == nil {
            activityIndicator = createActivityIndicator()
        }

        showSpinning()
    }

    func hideLoading() {
        self.title = originalButtonText
        activityIndicator?.stopAnimating()
    }

    private func createActivityIndicator() -> UIActivityIndicatorView {
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .primary
        return activityIndicator
    }

    private func showSpinning() {
        self.customView = activityIndicator
        activityIndicator.startAnimating()
    }

}
