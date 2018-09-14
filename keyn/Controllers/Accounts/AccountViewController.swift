import UIKit
import MBProgressHUD
import JustLog
import OneTimePassword


class AccountViewController: UITableViewController, UITextFieldDelegate {

    //MARK: Properties
    var editButton: UIBarButtonItem!
    var account: Account?
    var tap: UITapGestureRecognizer!
    var qrEnabled: Bool = true
    
    @IBOutlet weak var websiteNameTextField: UITextField!
    @IBOutlet weak var websiteURLTextField: UITextField!
    @IBOutlet weak var userNameTextField: UITextField!
    @IBOutlet weak var userPasswordTextField: UITextField!
    @IBOutlet weak var userCodeTextField: UITextField!
    @IBOutlet weak var showPasswordButton: UIButton!
    @IBOutlet weak var userCodeCell: UITableViewCell!
    @IBOutlet weak var totpLoader: UIView!
    @IBOutlet weak var totpLoaderWidthConstraint: NSLayoutConstraint!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        editButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.edit, target: self, action: #selector(edit))
        navigationItem.rightBarButtonItem = editButton
        
        if let account = account {
            do {
                websiteNameTextField.text = account.site.name
                websiteURLTextField.text = account.site.url
                userNameTextField.text = account.username
                userPasswordTextField.text = try account.password()
                try toggleOTPUI(account: account)
                websiteNameTextField.delegate = self
                websiteURLTextField.delegate = self
                userNameTextField.delegate = self
                userPasswordTextField.delegate = self
            } catch {
                // TODO: Present error to user?
                Logger.shared.error("Could not get password.", error: error as NSError)
            }
            navigationItem.title = account.site.name
            navigationItem.largeTitleDisplayMode = .never
        }
        
        tap = UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:)))
    }
    
    private func toggleOTPUI(account: Account) throws {
        if let hasOtp = account.hasOtp, hasOtp, let token = try account.oneTimePasswordToken() {
            qrEnabled = false
            totpLoaderWidthConstraint.constant = 44
            userCodeCell.accessoryType = .none
            userCodeTextField.text = token.currentPassword
            switch token.generator.factor {
            case .counter(let counter):
                print("Counter")
            case .timer(let period):
                let now = Date().timeIntervalSince1970
                let start = now.truncatingRemainder(dividingBy: period)
                let loadingCircle = LoadingCircle()
                totpLoader.addSubview(loadingCircle)
                func completion() {
                    userCodeTextField.text = token.currentPassword
                    loadingCircle.animateCircle(duration: period, start: 0.0, completion: completion)
                }
                loadingCircle.animateCircle(duration: period, start: start, completion: completion)
            }
        } else {
            qrEnabled = true
            totpLoaderWidthConstraint.constant = 0
            userCodeCell.accessoryType = .disclosureIndicator
            userCodeTextField.placeholder = "Scan QR code"
        }
    }
    
    
    // MARK: UITextFieldDelegate
    
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


    // MARK: Actions
    
    @IBAction func showPassword(_ sender: UIButton) {
        if userPasswordTextField.isEnabled {
            userPasswordTextField.isSecureTextEntry = !userPasswordTextField.isSecureTextEntry
        } else {
            showHiddenPasswordPopup()
        }
    }
    
    @IBAction func deleteAccount(_ sender: UIButton) {
        let alert = UIAlertController(title: "Delete account?", message: nil, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "Delete", style: .destructive, handler: { action in
            self.performSegue(withIdentifier: "DeleteAccount", sender: self)
        }))
        self.present(alert, animated: true, completion: nil)
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard indexPath.section == 1 else { return }
        if indexPath.row == 1 {
            copyPassword(indexPath)
        } else if indexPath.row == 2 && qrEnabled {
            performSegue(withIdentifier: "showQR", sender: self)
        }
    }
    
    @objc func edit() {
        let cancelButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.cancel, target: self, action: #selector(cancel))
        let doneButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.done, target: self, action: #selector(update))
        doneButton.style = .done
        
        navigationItem.setLeftBarButton(cancelButton, animated: true)
        navigationItem.setRightBarButton(doneButton, animated: true)
        
        userNameTextField.isEnabled = true
        userPasswordTextField.isEnabled = true
        websiteNameTextField.isEnabled = true
        websiteURLTextField.isEnabled = true
    }
    
    @objc func cancel() {
        endEditing()
        do {
            userPasswordTextField.text = try account?.password()
        } catch {
            Logger.shared.warning("Could not get password", error: error as NSError)
        }
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
            if let oldPassword: String = try account?.password() {
                newPassword = userPasswordTextField.text != oldPassword ? userPasswordTextField.text : nil
            }
            let newUrl = websiteURLTextField.text != account?.site.url ? websiteURLTextField.text : nil
            guard newPassword != nil || newUsername != nil || newSiteName != nil || newUrl != nil else {
                return
            }
            try account?.update(username: newUsername, password: newPassword, siteName: newSiteName, url: newUrl, hasOtp: nil)
            if let accountsTableViewController = navigationController?.viewControllers[0] as? AccountsTableViewController {
                accountsTableViewController.updateAccount(account: account!)
            }
        } catch {
            Logger.shared.warning("Could not change username", error: error as NSError)
            userNameTextField.text = account?.username
            websiteNameTextField.text = account?.site.name
            websiteURLTextField.text = account?.site.url
        }
    }
    
    
    // MARK: Private methods
    
    private func endEditing() {
        userPasswordTextField.isSecureTextEntry = true
        navigationItem.setLeftBarButton(nil, animated: true)
        navigationItem.setRightBarButton(editButton, animated: true)
        userNameTextField.isEnabled = false
        userPasswordTextField.isEnabled = false
        websiteNameTextField.isEnabled = false
        websiteURLTextField.isEnabled = false
    }
    
    private func showHiddenPasswordPopup() {
        do {
            let showPasswordHUD = MBProgressHUD.showAdded(to: self.tableView.superview!, animated: true)
            showPasswordHUD.mode = .text
            showPasswordHUD.bezelView.color = .black
            showPasswordHUD.label.text = try account?.password() ?? "Error fetching password"
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
            Logger.shared.error("Could not get account", error: error as NSError)
        }
    }
    
    private func copyPassword(_ indexPath: IndexPath) {
        guard let passwordCell = tableView.cellForRow(at: indexPath) else {
            return
        }
        
        Logger.shared.info("Password copied to pasteboard.", userInfo: ["code": AnalyticsMessage.passwordCopy.rawValue])
        
        let pasteBoard = UIPasteboard.general
        pasteBoard.string = userPasswordTextField.text
        
        let copiedLabel = UILabel(frame: passwordCell.bounds)
        copiedLabel.text = "Copied"
        copiedLabel.font = copiedLabel.font.withSize(18)
        copiedLabel.textAlignment = .center
        copiedLabel.textColor = .white
        copiedLabel.backgroundColor = UIColor(displayP3Red: 0.85, green: 0.85, blue: 0.85, alpha: 1)
        
        passwordCell.addSubview(copiedLabel)
        
        UIView.animate(withDuration: 0.5, delay: 1.0, options: [.curveLinear], animations: {
            copiedLabel.alpha = 0.0
        }) { if $0 { copiedLabel.removeFromSuperview() } }
    }
    
    
    // MARK: - Navigation
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        super.prepare(for: segue, sender: sender)
        if segue.identifier == "reportSite", let destination = segue.destination.contents as? ReportSiteViewController {
            destination.navigationItem.title = account?.site.name
            destination.account = account
        } else if segue.identifier == "showQR", let destination = segue.destination as? OTPViewController {
            destination.navigationItem.title = account?.site.name
            destination.account = account
        }
    }

}

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
    
    func animateCircle(duration: TimeInterval, start: TimeInterval, completion: @escaping () -> Void) {
        CATransaction.begin()
        CATransaction.setAnimationDuration(duration - start)
        CATransaction.setCompletionBlock(completion)
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.duration = duration - start
        circleLayer.strokeStart = 0
        circleLayer.strokeEnd = CGFloat(start / duration)
        animation.fromValue = CGFloat(start / duration)
        animation.toValue = 1
        animation.timingFunction = CAMediaTimingFunction(name: kCAMediaTimingFunctionLinear)
//        circleLayer.strokeEnd = 1.0
        circleLayer.add(animation, forKey: "animateCircle")
        CATransaction.commit()
    }
    
}
