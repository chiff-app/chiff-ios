//
//  BackupCircle.swift
//  keyn
//
//  Created by Bas Doorn on 20/06/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

class BackupCircle: CircleView {

    override func drawBackground(radius: CGFloat, color: CGColor) {
        guard backgroundLayer == nil else {
            return
        }
        let circleCenter = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let circlePath = UIBezierPath(arcCenter: circleCenter, radius: radius, startAngle: CGFloat(0 - Double.pi / 2), endAngle: CGFloat(3 * Double.pi / 2), clockwise: true)

        backgroundLayer = CAShapeLayer()
        backgroundLayer.path = circlePath.cgPath
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.strokeColor = color
        backgroundLayer.strokeStart = 0.0
        backgroundLayer.strokeEnd = 1.0
        backgroundLayer.lineWidth = 8

        layer.addSublayer(backgroundLayer)
    }

    override func drawCircle(radius: CGFloat, color: CGColor, initialPosition: CGFloat) {
        guard circleLayer == nil else {
            return
        }
        let circleCenter = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let circlePath = UIBezierPath(arcCenter: circleCenter, radius: radius, startAngle: CGFloat(0 - Double.pi / 2), endAngle: CGFloat(3 * Double.pi / 2), clockwise: true)

        circleLayer = CAShapeLayer()
        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = color
        circleLayer.strokeStart = 0.0
        circleLayer.strokeEnd = initialPosition
        circleLayer.lineWidth = 8

        layer.addSublayer(circleLayer)
    }

}
