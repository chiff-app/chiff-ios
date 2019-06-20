//
//  CircleView.swift
//  keyn
//
//  Created by Bas Doorn on 20/06/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit

protocol Circle: UIView {
    func drawBackground(radius: CGFloat, color: CGColor)
    func drawCircle(radius: CGFloat, color: CGColor, initialPosition: CGFloat)
    func animateCircle(from origin: CGFloat, to destination: CGFloat)
    func startCircleAnimation(duration: TimeInterval, start: TimeInterval)
    func removeCircleAnimation()
}

class CircleView: UIView, Circle {

    var circleLayer: CAShapeLayer!
    var backgroundLayer: CAShapeLayer!

    var isInitialized: Bool {
        return circleLayer != nil
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
    }

    func drawBackground(radius: CGFloat, color: CGColor) {
        fatalError("This function should be overrided")
    }

    func drawCircle(radius: CGFloat, color: CGColor, initialPosition: CGFloat) {
        fatalError("This function should be overrided")
    }

    func animateCircle(from origin: CGFloat, to destination: CGFloat) {
        guard circleLayer != nil else {
            print("Circlelayer not initialized yet")
            return
        }
        CATransaction.begin()
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.duration = 0.2
        circleLayer.strokeStart = 0
        circleLayer.strokeEnd = destination
        animation.fromValue = origin
        animation.toValue = destination
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        animation.isRemovedOnCompletion = false
        circleLayer.add(animation, forKey: "animateCircle")
        CATransaction.commit()
    }

    func removeCircleAnimation() {
        circleLayer?.removeAllAnimations()
    }

    func startCircleAnimation(duration: TimeInterval, start: TimeInterval) {
        CATransaction.begin()
        CATransaction.setCompletionBlock {
            self.animate(duration: duration, start: 0.0, infinite: true)
        }
        self.animate(duration: duration, start: start, infinite: false)
        CATransaction.commit()
    }

    private func animate(duration: TimeInterval, start: TimeInterval, infinite: Bool) {
        let animation = CABasicAnimation(keyPath: "strokeEnd")
        animation.duration = duration - start
        circleLayer.strokeStart = 0
        circleLayer.strokeEnd = CGFloat(start / duration)
        animation.fromValue = CGFloat(start / duration)
        animation.toValue = 1
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.linear)

        if infinite {
            animation.repeatCount = .infinity
        }

        animation.isRemovedOnCompletion = false
        circleLayer.add(animation, forKey: "animateCircle")
    }

    func draw(color: CGColor, backgroundColor: CGColor, radius: CGFloat? = nil, initialPosition: CGFloat = 0
    ) {
        drawBackground(radius: radius ?? bounds.width / 2, color: backgroundColor)
        drawCircle(radius: radius ?? bounds.width / 2, color: color, initialPosition: initialPosition)
    }

}
