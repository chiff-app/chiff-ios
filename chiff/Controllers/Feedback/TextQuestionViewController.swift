/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class TextQuestionViewController: QuestionViewController, UITextViewDelegate {
    @IBOutlet weak var textView: UITextView!
    @IBOutlet weak var scrollView: UIScrollView!
    @IBOutlet weak var contentView: UIView!
    @IBOutlet weak var constraintContentHeight: NSLayoutConstraint! // Should be raised to 1000 on keyboard show
    @IBOutlet weak var constraintMiddleDistance: NSLayoutConstraint!

    private let frameHeight: CGFloat = 480
    private let heightOffset: CGFloat = 64
    private let bottomOffset: CGFloat = 10
    private let hightLayoutPriority: UILayoutPriority = UILayoutPriority(999)
    private let lowLayoutPriority: UILayoutPriority = UILayoutPriority(990)
    private var lastOffset: CGPoint!
    private var keyboardHeight: CGFloat!

    override func viewDidLoad() {
        super.viewDidLoad()
        textView.delegate = self

        if self.view.frame.size.height > frameHeight {
            self.constraintContentHeight.constant = self.view.frame.size.height - heightOffset
        } else {
            constraintMiddleDistance.priority = hightLayoutPriority
        }

        view.layoutIfNeeded()
        textView.layer.cornerRadius = 4.0

        // Observe keyboard change
        let nc = NotificationCenter.default
        nc.addObserver(self, selector: #selector(keyboardWillShow(notification:)), name: UIResponder.keyboardWillShowNotification, object: nil)
        nc.addObserver(self, selector: #selector(keyboardWillHide(notification:)), name: UIResponder.keyboardWillHideNotification, object: nil)

        self.view.addGestureRecognizer(UITapGestureRecognizer(target: self.view, action: #selector(UIView.endEditing(_:))))
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
            keyboardHeight = keyboardSize.height
            // so increase contentView's height by keyboard height
            UIView.animate(withDuration: 0.3, animations: {
                self.constraintMiddleDistance.priority = self.hightLayoutPriority
                self.constraintContentHeight.constant += (self.keyboardHeight)
            })

            let distanceToBottom = self.scrollView.frame.size.height - (textView.frame.origin.y) - (textView.frame.size.height)

            guard self.lastOffset != nil else {
                return
            }

            // set new offset for scroll view
            UIView.animate(withDuration: 0.3, animations: {
                // scroll to the position above bottom 10 points
                self.scrollView.contentOffset = CGPoint(x: self.lastOffset.x, y: distanceToBottom + self.bottomOffset)
            })
        }
    }

    @objc func keyboardWillHide(notification: NSNotification) {
        guard keyboardHeight != nil else {
            return
        }

        UIView.animate(withDuration: 0.3) {
            if self.view.frame.size.height > self.frameHeight {
                self.constraintMiddleDistance.priority = self.lowLayoutPriority
            }
            self.constraintContentHeight.constant -= (self.keyboardHeight)
            self.scrollView.contentOffset = self.lastOffset
        }

        keyboardHeight = nil
    }

    @IBAction func submit(_ sender: UIButton) {
        question?.response = String(textView.text)

        if let navCon = self.navigationController as? QuestionnaireController {
            navCon.submitQuestion(index: questionIndex, question: question)
            navCon.nextQuestion()
        }
    }
}