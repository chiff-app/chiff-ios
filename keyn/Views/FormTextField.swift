/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

@IBDesignable
class FormTextField: LocalizableTextField {
    @IBInspectable var inset: CGFloat = 0
    
    override func textRect(forBounds bounds: CGRect) -> CGRect {
        return bounds.insetBy(dx: inset, dy: inset)
    }
    
    override func editingRect(forBounds bounds: CGRect) -> CGRect {
        return textRect(forBounds: bounds)
    }
}
