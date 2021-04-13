//
//  KeynButton.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

enum KeynButtonType: String {
    case primary
    case secondary
    case tertiary
    case accent
    case dark
    case darkSecondary
    case outline
}

@IBDesignable class KeynButton: LocalizableButton {

    @IBInspectable var keynButtonType: String {
        get {
            return self.type.rawValue
        }
        set(type) {
            self.type = KeynButtonType(rawValue: type) ?? .primary
        }
    }

    var originalButtonText: String?
    var activityIndicator: UIActivityIndicatorView!

    var type: KeynButtonType = .primary {
        didSet {
            switch type {
            case .primary:
                backgroundColor = UIColor.primary
                tintColor = UIColor.white
            case .secondary:
                backgroundColor = UIColor.primaryLight
                tintColor = UIColor.primary
            case .tertiary:
                backgroundColor = UIColor.white
                tintColor = UIColor.primary
                layer.borderColor = UIColor.primaryLight.cgColor
                layer.borderWidth = 1.0
            case .accent:
                backgroundColor = UIColor.secondary
                tintColor = UIColor.white
            case .dark:
                backgroundColor = UIColor.primaryDark
                tintColor = UIColor.white
            case .darkSecondary:
                backgroundColor = UIColor.primaryLight.withAlphaComponent(0.3)
                tintColor = UIColor.white
            case .outline:
                backgroundColor = UIColor.clear
                tintColor = UIColor.white.withAlphaComponent(0.8)
                layer.borderColor = UIColor.white.withAlphaComponent(0.3).cgColor
                layer.borderWidth = 1.0
            }
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        sharedInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        sharedInit()
    }

    override func prepareForInterfaceBuilder() {
        sharedInit()
        super.prepareForInterfaceBuilder()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layer.cornerRadius = frame.size.height / 2
    }

    func sharedInit() {
        layer.cornerRadius = frame.size.height / 2
        titleLabel?.font = UIFont(name: "Montserrat-Bold", size: 14.0)
    }

    func showLoading() {
        originalButtonText = self.titleLabel?.text
        self.setTitle("", for: .normal)

        if activityIndicator == nil {
            activityIndicator = createActivityIndicator()
        }

        showSpinning()
    }

    func hideLoading() {
        self.setTitle(originalButtonText, for: .normal)
        activityIndicator?.stopAnimating()
    }

    private func createActivityIndicator() -> UIActivityIndicatorView {
        let activityIndicator = UIActivityIndicatorView()
        activityIndicator.hidesWhenStopped = true
        activityIndicator.color = .white
        return activityIndicator
    }

    private func showSpinning() {
        activityIndicator.translatesAutoresizingMaskIntoConstraints = false
        self.addSubview(activityIndicator)
        centerActivityIndicatorInButton()
        activityIndicator.startAnimating()
    }

    private func centerActivityIndicatorInButton() {
        let xCenterConstraint = NSLayoutConstraint(item: self, attribute: .centerX, relatedBy: .equal, toItem: activityIndicator, attribute: .centerX, multiplier: 1, constant: 0)
        self.addConstraint(xCenterConstraint)

        let yCenterConstraint = NSLayoutConstraint(item: self, attribute: .centerY, relatedBy: .equal, toItem: activityIndicator, attribute: .centerY, multiplier: 1, constant: 0)
        self.addConstraint(yCenterConstraint)
    }

}
