//
//  MultiLineTextInputTableViewCell.swift
//  keyn
//
//  Created by Bas Doorn on 14/04/2020.
//  Copyright © 2020 keyn. All rights reserved.
//

import UIKit

protocol MultiLineTextInputTableViewCellDelegate {
    var maxCharacters: Int { get }
    var placeholderText: String { get }
    func textViewHeightDidChange(_ cell: UITableViewCell)
}

class MultiLineTextInputTableViewCell: UITableViewCell {

    @IBOutlet var textView: UITextView!

    var delegate: MultiLineTextInputTableViewCellDelegate!

    /// Custom setter so we can initialise the height of the text view
    var textString: String {
        get {
            guard textView.text != delegate.placeholderText else {
                return ""
            }
            return textView.text
        }
        set {
            if !newValue.isEmpty {
                textView.text = newValue
                textView.isSelectable = true
                textView.textColor = UIColor.textColor
            } else {
                textView.text = delegate.placeholderText
                textView.isSelectable = false
                textView.textColor = UIColor.lightGray
            }
            textViewDidChange(textView)
        }
    }

    var newSize: CGSize {
        return textView.sizeThatFits(CGSize(width: textView.bounds.size.width, height: CGFloat.greatestFiniteMagnitude))
    }

    override func awakeFromNib() {
        super.awakeFromNib()
        // Disable scrolling inside the text view so we enlarge to fitted size
        textView.isScrollEnabled = false
        textView.delegate = self
    }

    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        if selected {
            textView.becomeFirstResponder()
        } else {
            textView.resignFirstResponder()
        }
    }
}

extension MultiLineTextInputTableViewCell: UITextViewDelegate {

    func textViewDidChange(_ textView: UITextView) {
        // Resize the cell only when cell's size is changed
        if textView.bounds.size.height != newSize.height {
            delegate.textViewHeightDidChange(self)
        }
    }

    func textView(_ textView: UITextView, shouldChangeTextIn range: NSRange, replacementText text: String) -> Bool {
        let currentText = textView.text ?? ""
        guard let stringRange = Range(range, in: currentText) else { return false }
        let updatedText = currentText.replacingCharacters(in: stringRange, with: text)
        return updatedText.count <= delegate.maxCharacters
    }

    func textViewDidBeginEditing(_ textView: UITextView) {
        if textView.textColor == UIColor.lightGray {
            textView.text = nil
            textView.textColor = UIColor.textColor
            textView.isSelectable = true
        }
    }

    func textViewDidEndEditing(_ textView: UITextView) {
        if textView.text.isEmpty {
            textView.text = delegate.placeholderText
            textView.isSelectable = false
            textView.textColor = UIColor.lightGray
        }
    }

}
