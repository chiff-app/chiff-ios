//
//  LoadingCircle.swift
//  chiff
//
//  Copyright: see LICENSE.md
//

import UIKit

class FilledCircle: CircleView {

    override func drawBackground(radius: CGFloat, color: CGColor) {
        let circleCenter = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let backgroundPath = UIBezierPath(arcCenter: circleCenter, radius: CGFloat(radius - 1), startAngle: CGFloat(0), endAngle: CGFloat(Double.pi * 2), clockwise: true)
        backgroundLayer = CAShapeLayer()
        backgroundLayer.path = backgroundPath.cgPath
        backgroundLayer.fillColor = UIColor.clear.cgColor
        backgroundLayer.lineWidth = 2.0
        backgroundLayer.strokeColor = color
        layer.addSublayer(backgroundLayer)
    }

    override func drawCircle(radius: CGFloat, color: CGColor, initialPosition: CGFloat) {
        let circleCenter = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let circlePath = UIBezierPath(arcCenter: circleCenter, radius: CGFloat(radius / 2), startAngle: CGFloat(0 - Double.pi / 2), endAngle: CGFloat(3 * Double.pi / 2), clockwise: true)
        circleLayer = CAShapeLayer()
        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = color
        circleLayer.strokeStart = 0.0
        circleLayer.strokeEnd = initialPosition
        circleLayer.lineWidth = CGFloat(radius)
        layer.addSublayer(circleLayer)
    }

}
