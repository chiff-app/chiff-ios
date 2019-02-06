/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import JustLog

class ReportSiteViewController: UIViewController, UITextViewDelegate {
    var account: Account?
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var loginReport: UISwitch!
    @IBOutlet weak var changeReport: UISwitch!
    @IBOutlet weak var addReport: UISwitch!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var constraintContentHeight: NSLayoutConstraint!

    var lastOffset: CGPoint!
    var keyboardHeight: CGFloat!

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.delegate = self

        // Observe keyboard change
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: NSNotification.Name.UIKeyboardWillShow, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: NSNotification.Name.UIKeyboardWillHide, object: nil)

        // Do any additional setup after loading the view.
        contentView.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
    }

    func textViewShouldBeginEditing(_ textView: UITextView) -> Bool {
        lastOffset = self.scrollView.contentOffset
        return true
    }

    func textViewShouldEndEditing(_ textView: UITextView) -> Bool {
        return true
    }

    @objc func keyboardWillShow(notification: NSNotification) {
        guard keyboardHeight == nil else {
            return
        }
        if let keyboardSize = (notification.userInfo?[UIKeyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            keyboardHeight = keyboardSize.height
            // so increase contentView's height by keyboard height
            UIView.animate(withDuration: 0.3, animations: {
                self.constraintContentHeight.constant += (self.keyboardHeight - 80)
            })

            let distanceToBottom = self.scrollView.frame.size.height - (textView.frame.origin.y) - (textView.frame.size.height)

            // set new offset for scroll view
            UIView.animate(withDuration: 0.3, animations: {
                // scroll to the position above bottom 10 points
                self.scrollView.contentOffset = CGPoint(x: self.lastOffset.x, y: distanceToBottom + 10)
            })
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        UIView.animate(withDuration: 0.3) {
            self.constraintContentHeight.constant -= (self.keyboardHeight - 80)
            self.scrollView.contentOffset = self.lastOffset
        }

        keyboardHeight = nil
    }

    // MARK: - Actions

    @IBAction func send(_ sender: UIBarButtonItem) {
        guard let account = account else {
            Logger.shared.error("Account was nil")
            return
        }

        Logger.shared.warning("Site reported.", userInfo: [
            "code": AnalyticsMessage.siteReported.rawValue,
            "siteID": account.site.id,
            "siteName": account.site.name,
            "loginError": loginReport.isOn,
            "changeError": changeReport.isOn,
            "addError": addReport.isOn,
            "remarks": textView.text
            ])

        dismiss(animated: true, completion: nil)
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}
