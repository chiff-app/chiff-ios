//
//  KeynTableViewController.swift
//  keyn
//
//  Created by Bas Doorn on 22/03/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class KeynNavigationController: UINavigationController {

    private let heightForLargeState: CGFloat = 58
    private let widthForLargeState: CGFloat = 52
    private let imageBottomMarginForLargeState: CGFloat = 7
    private let navBarHeightLargeState: CGFloat = 96.5

    private let heightForSmallState: CGFloat = 34.8
    private let widthForSmallState: CGFloat = 31.2
    private let imageBottomMarginForSmallState: CGFloat = 4.2
    private let navBarHeightSmallState: CGFloat = 44

    private let logoImageView = UIImageView(image: UIImage(named: "logo_purple"))

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationBar.addSubview(logoImageView)
        logoImageView.clipsToBounds = true
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: navigationBar.centerXAnchor),
            logoImageView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -imageBottomMarginForLargeState),
            logoImageView.heightAnchor.constraint(equalToConstant: heightForLargeState),
            logoImageView.widthAnchor.constraint(equalToConstant: widthForLargeState)
        ])
    }

    func moveAndResizeImage() {
        let height = navigationBar.frame.height
        let coeff: CGFloat = {
            let delta = height - heightForSmallState
            let heightDifferenceBetweenStates = (navBarHeightLargeState - navBarHeightSmallState)
            return delta / heightDifferenceBetweenStates
        }()

        let factor = heightForSmallState / heightForLargeState

        let scale: CGFloat = {
            let sizeAddendumFactor = coeff * (1.0 - factor)
            return min(1.0, sizeAddendumFactor + factor)
        }()

        let sizeDiff = heightForLargeState * (1.0 - factor) // 8.0
        let yTranslation: CGFloat = {
            let maxYTranslation = imageBottomMarginForLargeState - imageBottomMarginForSmallState + sizeDiff
            return max(0, min(maxYTranslation, (maxYTranslation - coeff * (imageBottomMarginForSmallState + sizeDiff))))
        }()

        logoImageView.transform = CGAffineTransform.identity
            .scaledBy(x: scale, y: scale)
            .translatedBy(x: 0, y: yTranslation)
    }

}
