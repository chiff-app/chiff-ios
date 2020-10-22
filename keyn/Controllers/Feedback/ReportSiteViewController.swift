/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import PromiseKit

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

        textView.layer.cornerRadius = 4.0

        // Do any additional setup after loading the view.
        contentView.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
        navigationItem.leftBarButtonItem?.setColor(color: .white)
        navigationItem.rightBarButtonItem?.setColor(color: .white)
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
        let message = """
        Hallo,

        Er is iets mis de volgende website:

        id:         \(account.site.id)
        site:       \(account.site.name)
        login werkt \(loginReport.isOn ? "niet" : "wel")
        change werkt \(changeReport.isOn ? "niet" : "wel")
        add werkt \(addReport.isOn ? "niet" : "wel")
        toevoegingen:
        \(textView.text ?? "")

        Groetjes!
        id: \(Properties.userId ?? "not set")
        """
        firstly {
            API.shared.request(path: "analytics", parameters: nil, method: .put, signature: nil, body: message.data)
        }.ensure(on: DispatchQueue.main) {
            self.dismiss(animated: true, completion: nil)
        }.catchLog("Error posting feedback")
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        dismiss(animated: true, completion: nil)
    }
}
