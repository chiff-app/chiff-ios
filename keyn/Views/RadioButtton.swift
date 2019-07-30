//
//  CircleView.swift
//  keyn
//
//  Created by Bas Doorn on 20/06/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class RadioButton: UIView {

    var enabled = false {
        didSet {
            innerCircle.isHidden = !enabled
        }
    }

    var innerCircle: CAShapeLayer!
    var outerCircle: CAShapeLayer!

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        drawOuterCircle()
        drawInnerCircle()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        drawOuterCircle()
        drawInnerCircle()
    }

    func drawInnerCircle() {
        let radius = (bounds.width / 2) * (4/9)
        let circleCenter = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let path = UIBezierPath(arcCenter: circleCenter, radius: radius, startAngle: CGFloat(0), endAngle: CGFloat(Double.pi * 2), clockwise: true)
        innerCircle = CAShapeLayer()
        innerCircle.path = path.cgPath
        innerCircle.fillColor = UIColor.primary.cgColor
        innerCircle.isHidden = true
        layer.addSublayer(innerCircle)
    }

    func drawOuterCircle() {
        let radius = bounds.width / 2
        let circleCenter = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let path = UIBezierPath(arcCenter: circleCenter, radius: radius, startAngle: CGFloat(0), endAngle: CGFloat(Double.pi * 2), clockwise: true)
        outerCircle = CAShapeLayer()
        outerCircle.path = path.cgPath
        outerCircle.fillColor = UIColor.clear.cgColor
        outerCircle.strokeColor = UIColor.primaryHalfOpacity.cgColor
        outerCircle.strokeStart = 0.0
        outerCircle.strokeEnd = 1.0
        outerCircle.lineWidth = 1.0
        layer.addSublayer(outerCircle)
    }

}
