/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class ReportSiteViewController: UIViewController, UITextViewDelegate {
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var loginReport: UISwitch!
    @IBOutlet weak var changeReport: UISwitch!
    @IBOutlet weak var addReport: UISwitch!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var constraintContentHeight: NSLayoutConstraint!

    var account: Account!
    
    private let KEYBOARD_OFFSET: CGFloat = 80
    private let BOTTOM_OFFSET: CGFloat = 10
    private var lastOffset: CGPoint!
    private var keyboardHeight: CGFloat!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.delegate = self

        // Observe keyboard change
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        // Do any additional setup after loading the view.
        contentView.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
        navigationItem.leftBarButtonItem?.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.primaryBold!], for: UIControl.State.normal)
        navigationItem.rightBarButtonItem?.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.primaryBold!], for: UIControl.State.normal)
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
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

        if let keyboardSize = (notification.userInfo?[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue {
            keyboardHeight = keyboardSize.height - self.KEYBOARD_OFFSET
            // so increase contentView's height by keyboard height
            UIView.animate(withDuration: 0.3, animations: {
                self.constraintContentHeight.constant += self.keyboardHeight
            })

            let distanceToBottom = self.scrollView.frame.size.height - (textView.frame.origin.y) - (textView.frame.size.height)

            // set new offset for scroll view
            UIView.animate(withDuration: 0.3, animations: {
                // scroll to the position above bottom 10 points
                self.scrollView.contentOffset = CGPoint(x: self.lastOffset.x, y: distanceToBottom + self.BOTTOM_OFFSET)
            })
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        UIView.animate(withDuration: 0.3) {
            self.constraintContentHeight.constant -= (self.keyboardHeight)
            self.scrollView.contentOffset = self.lastOffset
        }

        keyboardHeight = nil
    }

    // MARK: - Actions

    @IBAction func send(_ sender: UIBarButtonItem) {
        Logger.shared.warning("Site reported.", userInfo: [
            "code": AnalyticsMessage.siteReported.rawValue,
            "siteID": account.site.id,
            "siteName": account.site.name,
            "loginError": loginReport.isOn,
            "changeError": changeReport.isOn,
            "addError": addReport.isOn,
            "remarks": textView.text ?? ""
        ])

        let message = """
        Hallo,

        Er is iets mis de volgende website:

        id:         \(account.site.id)
        site:       \(account.site.name)
        login werkt \(loginReport.isOn ? "niet" : "wel")
        change werkt \(changeReport.isOn ? "niet" : "wel")
        add werkt \(addReport.isOn ? "niet" : "wel")
        toevingen:
        \(textView.text ?? "")

        Groetjes!
        """
        API.shared.request(endpoint: .analytics, path: nil, parameters: nil, method: .post, body: message.data) { (_, error) in
            if let error = error {
                Logger.shared.warning("Error posting feedback", error: error)
            }
            DispatchQueue.main.async {
                self.dismiss(animated: true, completion: nil)
            }
        }

    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}
