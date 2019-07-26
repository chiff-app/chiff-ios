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

    let logoImageView = UIImageView(image: UIImage(named: "logo"))

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        logoImageView.tintColor = UIColor.primary
        setNeedsStatusBarAppearanceUpdate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        logoImageView.contentMode = .scaleAspectFit
        navigationBar.addSubview(logoImageView)
        logoImageView.clipsToBounds = false
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.tintColor = UIColor.primary
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: navigationBar.centerXAnchor),
            logoImageView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -imageBottomMargin),
            logoImageView.heightAnchor.constraint(equalToConstant: height),
        ])
        addBackgroundLayer()
    }

    private func addBackgroundLayer() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = navigationBar.bounds
        var colors = [CGColor]()
        colors.append(UIColor.primaryVeryLight.withAlphaComponent(1).cgColor)
        colors.append(UIColor.primaryVeryLight.withAlphaComponent(0).cgColor)
        gradientLayer.locations = [NSNumber(value: 0.0), NSNumber(value: 0.8)]
        gradientLayer.colors = colors
        if let image = getImageFrom(gradientLayer: gradientLayer) {
            navigationBar.setBackgroundImage(image, for: UIBarMetrics.default)
        }
    }

    private func getImageFrom(gradientLayer:CAGradientLayer) -> UIImage? {
        var gradientImage:UIImage?
        UIGraphicsBeginImageContext(gradientLayer.frame.size)
        if let context = UIGraphicsGetCurrentContext() {
            gradientLayer.render(in: context)
            gradientImage = UIGraphicsGetImageFromCurrentImageContext()?.resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        }
        UIGraphicsEndImageContext()
        return gradientImage
    }
}
