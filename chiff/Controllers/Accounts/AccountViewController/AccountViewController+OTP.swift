/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import OneTimePassword
import QuartzCore

extension AccountViewController {

    func updateOTPUI() {
        var otpCodeTimer: Timer?

        if let token = token {
            qrEnabled = false
            totpLoaderWidthConstraint.constant = UITableViewCell.defaultHeight
            userCodeCell.updateConstraints()
            userCodeCell.accessoryView = nil
            userCodeTextField.text = token.currentPasswordSpaced
            switch token.generator.factor {
            case .counter:
                let button = UIButton(frame: CGRect(x: 0, y: 0, width: 44, height: 44))
                button.imageEdgeInsets = UIEdgeInsets(top: 12, left: 12, bottom: 12, right: 12)
                button.setImage(UIImage(named: "refresh"), for: .normal)
                button.imageView?.contentMode = .scaleAspectFit
                button.addTarget(self, action: #selector(self.updateHOTP), for: .touchUpInside)
                totpLoader.addSubview(button)
            case .timer(let period):
                let start = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: period)
                loadingCircle?.removeCircleAnimation()
                totpLoader.subviews.forEach { $0.removeFromSuperview() }
                self.loadingCircle = FilledCircle(frame: CGRect(x: 12, y: 12, width: 20, height: 20))
                loadingCircle?.draw(color: UIColor.primary.cgColor, backgroundColor: UIColor.primary.cgColor)
                totpLoader.addSubview(self.loadingCircle!)
                otpCodeTimer = Timer.scheduledTimer(withTimeInterval: period - start, repeats: false, block: { (_) in
                    self.userCodeTextField.text = token.currentPasswordSpaced
                    otpCodeTimer = Timer.scheduledTimer(timeInterval: period, target: self, selector: #selector(self.updateTOTP), userInfo: nil, repeats: true)
                })
                loadingCircle!.startCircleAnimation(duration: period, start: start)
            }
        } else {
            userCodeTextField.text = ""
            otpCodeTimer?.invalidate()
            qrEnabled = true
            loadingCircle?.removeCircleAnimation()
            totpLoader.subviews.forEach { $0.removeFromSuperview() }
            totpLoaderWidthConstraint.constant = 0
            userCodeCell.updateConstraints()
            userCodeCell.accessoryView = UIImageView(image: UIImage(named: "chevron_right"))
            userCodeTextField.placeholder = "accounts.scan_qr".localized
        }
    }

    @objc func updateHOTP() {
        if let token = token?.updatedToken(), var account = self.account as? UserAccount {
            self.token = token
            try? account.setOtp(token: token)
            userCodeTextField.text = token.currentPasswordSpaced
        }
    }

    @objc func updateTOTP() {
        userCodeTextField.text = token?.currentPasswordSpaced ?? ""
    }
}
