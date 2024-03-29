//
//  chiffNavigationController.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

@IBDesignable class ChiffNavigationController: UINavigationController {

    private let height: CGFloat = 38
    private let imageTopMargin: CGFloat = 0
    private var gradientLayer: CAGradientLayer!

    @IBInspectable var gradientColor: UIColor = .primaryVeryLight
    @IBInspectable var logoColor: UIColor = .primary
    @IBInspectable var gradientEnabled: Bool = true

    let logoImageView = UIImageView(image: UIImage(named: "logo"))

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .default
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        logoImageView.tintColor = logoColor
        setNeedsStatusBarAppearanceUpdate()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        logoImageView.contentMode = .scaleAspectFit
        navigationBar.addSubview(logoImageView)
        logoImageView.clipsToBounds = false
        logoImageView.translatesAutoresizingMaskIntoConstraints = false
        logoImageView.tintColor = logoColor
        NSLayoutConstraint.activate([
            logoImageView.centerXAnchor.constraint(equalTo: navigationBar.centerXAnchor),
            logoImageView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -imageTopMargin),
            logoImageView.heightAnchor.constraint(equalToConstant: height)
        ])
    }

    override func viewDidLayoutSubviews() {
        addBackgroundLayer()
        gradientLayer.isHidden = !gradientEnabled
    }

    // MARK: - Private functions

    private func addBackgroundLayer() {
        gradientLayer = CAGradientLayer()
        gradientLayer.frame = navigationBar.frame
        var colors = [CGColor]()
        colors.append(gradientColor.withAlphaComponent(1).cgColor)
        colors.append(gradientColor.withAlphaComponent(0).cgColor)
        gradientLayer.locations = [NSNumber(value: 0.0), NSNumber(value: 0.5)]
        gradientLayer.colors = colors
        if let image = getImageFrom(gradientLayer: gradientLayer) {
            navigationBar.setBackgroundImage(image, for: UIBarMetrics.default)
        }
    }

    private func getImageFrom(gradientLayer: CAGradientLayer) -> UIImage? {
        var gradientImage: UIImage?
        UIGraphicsBeginImageContext(gradientLayer.frame.size)
        if let context = UIGraphicsGetCurrentContext() {
            gradientLayer.render(in: context)
            gradientImage = UIGraphicsGetImageFromCurrentImageContext()?.resizableImage(withCapInsets: UIEdgeInsets.zero, resizingMode: .stretch)
        }
        UIGraphicsEndImageContext()
        return gradientImage
    }
}
