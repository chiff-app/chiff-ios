/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import MBProgressHUD
import OneTimePassword
import QuartzCore

protocol canAddOTPCode {
    func addOTPCode(token: Token)
}

class AccountViewController: UITableViewController, UITextFieldDelegate, canAddOTPCode {
    @IBOutlet weak var websiteNameTextField: UITextField!
    @IBOutlet weak var websiteURLTextField: UITextField!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var userPasswordTextField: UITextField!
    @IBOutlet weak var userCodeTextField: UITextField!
    @IBOutlet weak var showPasswordButton: UIButton!
    @IBOutlet weak var userCodeCell: UITableViewCell!
    @IBOutlet weak var totpLoader: UIView!
    @IBOutlet weak var totpLoaderWidthConstraint: NSLayoutConstraint!

    var editButton: UIBarButtonItem!
    var account: Account!
    var tap: UITapGestureRecognizer!
    var qrEnabled: Bool = true
    var editingMode: Bool = false
    var otpCodeTimer: Timer?
    var token: Token?
    var loadingCircle: LoadingCircle?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        editButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.edit, target: self, action: #selector(edit))
        navigationItem.rightBarButtonItem = editButton
        
        do {
            websiteNameTextField.text = account.site.name
            websiteURLTextField.text = account.site.url
            userNameTextField.text = account.username
            userPasswordTextField.text = account.password
            token = try account.oneTimePasswordToken()
            updateOTPUI()
            websiteNameTextField.delegate = self
            websiteURLTextField.delegate = self
            userNameTextField.delegate = self
            userPasswordTextField.delegate = self
        } catch {
            // TODO: Present error to user?
            Logger.shared.error("Could not get password.", error: error)
        }
        navigationItem.title = account.site.name
        navigationItem.largeTitleDisplayMode = .never
        
        tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
    }
    
    // MARK: - UITableView
    
    override func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return indexPath.section == 1 && indexPath.row == 2 && token != nil && tableView.isEditing
    }
    
    override func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        try? self.account.deleteOtp()
        self.token = nil
        DispatchQueue.main.async {
            self.updateOTPUI()
        }
        tableView.cellForRow(at: indexPath)?.setEditing(false, animated: true)

    }
    
    // MARK: - UITextFieldDelegate
    
    // Hide the keyboard.
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
    func textFieldDidBeginEditing(_ textField: UITextField) {
        view.addGestureRecognizer(tap)
    }
    
    func textFieldDidEndEditing(_ textField: UITextField) {
        if textField == websiteNameTextField {
             navigationItem.title = textField.text
        }
        view.removeGestureRecognizer(tap)
    }
    
    // TODO: Perhaps hide cell if TOTP is not possible for site. But should be registered somewhere
//    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
//        if indexPath.section == 1 && indexPath.row == 2, let account = account {
//            return account.hasOtp ?? false ? 44 : 0
//        }
//        return 44
//    }

    // MARK: - Actions
    
    @IBAction func showPassword(_ sender: UIButton) {
        if userPasswordTextField.isEnabled {
            userPasswordTextField.isSecureTextEntry = !userPasswordTextField.isSecureTextEntry
        } else {
            showHiddenPasswordPopup()
        }
    }
    
    @IBAction func deleteAccount(_ sender: UIButton) {
        let alert = UIAlertController(title: "delete_account".localized, message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "cancel".localized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "delete".localized, style: .destructive, handler: { action in
            self.performSegue(withIdentifier: "DeleteAccount", sender: self)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 1 else { return }
        if indexPath.row == 1 || (indexPath.row == 2 && !qrEnabled) {
            copyToPasteboard(indexPath)
        } else if indexPath.row == 2 && qrEnabled {
            performSegue(withIdentifier: "showQR", sender: self)
        }
    }
    
    @objc func edit() {
        tableView.setEditing(true, animated: true)
        let cancelButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.cancel, target: self, action: #selector(cancel))
        let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(update))
        doneButton.style = .done
        
        navigationItem.setLeftBarButton(cancelButton, animated: true)
        navigationItem.setRightBarButton(doneButton, animated: true)
        
        userNameTextField.isEnabled = true
        userPasswordTextField.isEnabled = true
        websiteNameTextField.isEnabled = true
        websiteURLTextField.isEnabled = true
        totpLoader?.isHidden = true

        editingMode = true
    }
    
    @objc func cancel() {
        endEditing()
        userPasswordTextField.text = account?.password
        navigationItem.title = account?.site.name
        userNameTextField.text = account?.username
        websiteNameTextField.text = account?.site.name
        websiteURLTextField.text = account?.site.url
    }
    
    @objc func update() {
        endEditing()
        do {
            var newPassword: String? = nil
            let newUsername = userNameTextField.text != account?.username ? userNameTextField.text : nil
            let newSiteName = websiteNameTextField.text != account?.site.name ? websiteNameTextField.text : nil
            if let oldPassword: String = account?.password {
                newPassword = userPasswordTextField.text != oldPassword ? userPasswordTextField.text : nil
            }
            let newUrl = websiteURLTextField.text != account?.site.url ? websiteURLTextField.text : nil
            guard newPassword != nil || newUsername != nil || newSiteName != nil || newUrl != nil else {
                return
            }
            try account?.update(username: newUsername, password: newPassword, siteName: newSiteName, url: newUrl)
            if let accountsTableViewController = navigationController?.viewControllers[0] as? AccountsTableViewController {
                accountsTableViewController.updateAccount(account: account!)
            }
        } catch {
            Logger.shared.warning("Could not change username", error: error)
            userNameTextField.text = account?.username
            websiteNameTextField.text = account?.site.name
            websiteURLTextField.text = account?.site.url
        }
    }
    
    
    // MARK: - Private
    
    private func endEditing() {
        tableView.setEditing(false, animated: true)
        userPasswordTextField.isSecureTextEntry = true
        navigationItem.setLeftBarButton(nil, animated: true)
        navigationItem.setRightBarButton(editButton, animated: true)
        userNameTextField.isEnabled = false
        userPasswordTextField.isEnabled = false
        websiteNameTextField.isEnabled = false
        websiteURLTextField.isEnabled = false
        totpLoader?.isHidden = false
        
        editingMode = false
    }
    
    private func showHiddenPasswordPopup() {
        do {
            let showPasswordHUD = MBProgressHUD.showAdded(to: self.tableView.superview!, animated: true)
            showPasswordHUD.mode = .text
            showPasswordHUD.bezelView.color = .black
            showPasswordHUD.label.text = account?.password ?? "password_error".localized
            showPasswordHUD.label.textColor = .white
            showPasswordHUD.label.font = UIFont(name: "Courier New", size: 24)
            showPasswordHUD.margin = 10
            showPasswordHUD.label.numberOfLines = 0
            showPasswordHUD.removeFromSuperViewOnHide = true
            showPasswordHUD.addGestureRecognizer(
                UITapGestureRecognizer(
                    target: showPasswordHUD,
                    action: #selector(showPasswordHUD.hide(animated:)))
            )
        } catch {
            Logger.shared.error("Could not get account", error: error)
        }
    }
    
    private func copyToPasteboard(_ indexPath: IndexPath) {
        guard let cell = tableView.cellForRow(at: indexPath) else {
            return
        }
        
        Logger.shared.analytics("\(indexPath.row == 1 ? "Password" : "OTP-code") copied to pasteboard.", code: .passwordCopy)
        
        let pasteBoard = UIPasteboard.general
        pasteBoard.string = indexPath.row == 1 ? userPasswordTextField.text : userCodeTextField.text
        
        let copiedLabel = UILabel(frame: cell.bounds)
        copiedLabel.text = "copied".localized
        copiedLabel.font = copiedLabel.font.withSize(18)
        copiedLabel.textAlignment = .center
        copiedLabel.textColor = .white
        copiedLabel.backgroundColor = UIColor(displayP3Red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        
        cell.addSubview(copiedLabel)
        
        UIView.animate(withDuration: 0.5, delay: 1.0, options: [.curveLinear], animations: {
            copiedLabel.alpha = 0.0
        }) { if $0 { copiedLabel.removeFromSuperview() } }
    }
    
    // MARK: OTP methods
    
    private func updateOTPUI() {
        if let token = token {
            qrEnabled = false
            totpLoaderWidthConstraint.constant = UITableViewCell.defaultHeight
            userCodeCell.updateConstraints()
            userCodeCell.accessoryType = .none
            userCodeTextField.text = token.currentPassword
            switch token.generator.factor {
            case .counter(_):
                let button = UIButton(frame: CGRect(x: 10, y: 10, width: 24, height: 24))
                button.setImage(UIImage(named: "refresh"), for: .normal)
                button.imageView?.contentMode = .scaleAspectFit
                button.addTarget(self, action: #selector(self.updateHOTP), for: .touchUpInside)
                totpLoader.addSubview(button)
            case .timer(let period):
                let start = Date().timeIntervalSince1970.truncatingRemainder(dividingBy: period)
                loadingCircle?.removeAnimations()
                totpLoader.subviews.forEach { $0.removeFromSuperview() }
                self.loadingCircle = LoadingCircle()
                totpLoader.addSubview(self.loadingCircle!)
                self.otpCodeTimer = Timer.scheduledTimer(withTimeInterval: period - start, repeats: false, block: { (timer) in
                    self.userCodeTextField.text = token.currentPassword
                    self.otpCodeTimer = Timer.scheduledTimer(timeInterval: period, target: self, selector: #selector(self.updateTOTP), userInfo: nil, repeats: true)
                })
                loadingCircle!.animateCircle(duration: period, start: start)
            }
        } else {
            userCodeTextField.text = ""
            otpCodeTimer?.invalidate()
            qrEnabled = true
            loadingCircle?.removeAnimations()
            totpLoader.subviews.forEach { $0.removeFromSuperview() }
            totpLoaderWidthConstraint.constant = 0
            userCodeCell.updateConstraints()
            userCodeCell.accessoryType = .disclosureIndicator
            userCodeTextField.placeholder = "add_otp_code".localized
        }
    }
    
    @objc func updateHOTP() {
        if let token = token?.updatedToken() {
            self.token = token
            try? account.setOtp(token: token)
            userCodeTextField.text = token.currentPassword
        }
    }
    
    @objc func updateTOTP() {
        userCodeTextField.text = token?.currentPassword ?? ""
    }

    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "reportSite", let destination = segue.destination.contents as? ReportSiteViewController {
            guard let account = account else {
                return
            }
            destination.navigationItem.title = account.site.name
            destination.account = account
        } else if segue.identifier == "showQR", let destination = segue.destination as? OTPViewController {
            self.loadingCircle?.removeAnimations()
            destination.navigationItem.title = account?.site.name
            destination.accountViewDelegate = self
            destination.account = account
        }
    }
    
    func addOTPCode(token: Token) {
        if editingMode {
            endEditing()
        }

        self.token = token
        updateOTPUI()
    }
}

// TODO: Frank: Shouldn't this be inner class of controller?
class LoadingCircle: UIView {
    var backgroundLayer: CAShapeLayer!
    var circleLayer: CAShapeLayer!
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        let radius = 13
        let backgroundPath = UIBezierPath(arcCenter: CGPoint(x: 22, y: 22), radius: CGFloat(radius - 1), startAngle: CGFloat(0), endAngle:CGFloat(Double.pi * 2), clockwise: true)
        backgroundLayer = CAShapeLayer()
        backgroundLayer.path = backgroundPath.cgPath
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.lineWidth = 2.0
        backgroundLayer.strokeColor = UIColor.lightGray.cgColor
        
        let circlePath = UIBezierPath(arcCenter: CGPoint(x: 22, y: 22), radius: CGFloat(radius / 2), startAngle: CGFloat(0 - Double.pi / 2), endAngle:CGFloat(3 * Double.pi / 2), clockwise: true)
        circleLayer = CAShapeLayer()
        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor.lightGray.cgColor
        circleLayer.strokeStart = 0.0
        circleLayer.strokeEnd = 1.0
        circleLayer.lineWidth = CGFloat(radius)

        layer.addSublayer(backgroundLayer)
        layer.addSublayer(circleLayer)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    func removeAnimations() {
        circleLayer.removeAllAnimations()
    }
    
    func animateCircle(duration: TimeInterval, start: TimeInterval) {
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            self.animate(duration: duration, start: 0.0, infinite: true)
        }
        self.animate(duration: duration, start: start, infinite: false)
        CATransaction.commit()
    }

    private func animate(duration: TimeInterval, start: TimeInterval, infinite: Bool) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.duration = duration - start
        circleLayer.strokeStart = 0
        circleLayer.strokeEnd = CGFloat(start / duration)
        animation.fromValue = CGFloat(start / duration)
        animation.toValue = 1
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)

        if infinite {
            animation.repeatCount = .infinity
        }

        animation.isRemovedOnCompletion = false
        circleLayer.add(animation, forKey: "animateCircle")
    }
}
