//
//  AttributedLabel.swift
//  keyn
//
//  Created by Bas Doorn on 20/03/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

@IBDesignable class AttributedLabel: UILabel {

    @IBInspectable var fontSize: CGFloat = 14.0

    @IBInspectable var fontFamily: String = "Montserrat-Medium"

    @IBInspectable var lineHeight: CGFloat = 1.0

    override func awakeFromNib() {
        let attrString = self.attributedText != nil ? NSMutableAttributedString(attributedString: self.attributedText!) : NSMutableAttributedString(string: "")
        attrString.addAttribute(NSAttributedString.Key.font, value: UIFont(name: self.fontFamily, size: self.fontSize)!, range: NSMakeRange(0, attrString.length))
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = self.lineHeight // Whatever line spacing you want in points
        attrString.addAttribute(NSAttributedString.Key.paragraphStyle, value:paragraphStyle, range:NSMakeRange(0, attrString.length))
        self.attributedText = attrString
    }
}
