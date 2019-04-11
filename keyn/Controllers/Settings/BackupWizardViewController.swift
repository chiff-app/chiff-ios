/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit

class BackupWizardViewController: UIViewController {
    @IBOutlet weak var wordLabel: UILabel!
    @IBOutlet weak var previousButton: UIButton!
    @IBOutlet weak var counterLabel: UILabel!
    @IBOutlet weak var backupCircle: BackupCircle!

    var mnemonic: [String]?
    var counter: Int = 0 {
        didSet {
            counterLabel.text = "\(counter + 1) / \(mnemonic!.count)"
            backupCircle.animateCircle(from: CGFloat(oldValue + 1), to: CGFloat(counter + 1))
        }
    }

    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }


    override func viewDidLoad() {
        super.viewDidLoad()
        do {
            mnemonic = try Seed.mnemonic()
            wordLabel.text = mnemonic![counter]
            counterLabel.text = "\(counter + 1) / \(mnemonic!.count)"
        } catch {
            Logger.shared.error("Error getting mnemonic.", error: error)
        }
        navigationItem.leftBarButtonItem?.setTitleTextAttributes([.foregroundColor: UIColor.white, .font: UIFont.primaryBold!], for: UIControl.State.normal)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        backupCircle.addCircles()
    }

    // MARK: - Actions

    @IBAction func next(_ sender: UIButton) {
        if counter < mnemonic!.count - 1 {
            counter += 1
            wordLabel.text = mnemonic![counter]
            if (counter >= 1) {
                previousButton.isEnabled = true
                previousButton.alpha = 1.0
            }
        } else {
           performSegue(withIdentifier: "MnemonicCheck", sender: self)

//            navigationController?.pushViewController(checkViewController, animated: true)
        }
    }

    @IBAction func previous(_ sender: UIButton) {
        if counter > 0 {
            counter -= 1
            wordLabel.text = mnemonic![counter]
            if (counter <= 0) {
                previousButton.isEnabled = false
                previousButton.alpha = 0.5
            }
        }
    }

    @IBAction func cancel(_ sender: UIBarButtonItem) {
        let alert = UIAlertController(title: "\("popups.questions.cancel_backup".localized.capitalized)", message: "popups.questions.cancel_backup_description".localized, preferredStyle: .actionSheet)
        alert.addAction(UIAlertAction(title: "popups.responses.continue".localized.capitalized, style: .cancel, handler: nil))
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized.capitalized, style: .destructive, handler: { action in
            self.performSegue(withIdentifier: "UnwindToSettings", sender: self)
        }))
        self.present(alert, animated: true, completion: nil)
    }

    // MARK: - Navigation

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? BackupCheckViewController {
            destination.mnemonic = mnemonic
        }
    }

}

class BackupCircle: UIView {

    var circleLayer: CAShapeLayer!
    var backgroundCircleLayer: CAShapeLayer!
    var isInitialized: Bool {
        return circleLayer != nil
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

    func addCircles() {
        guard circleLayer == nil else {
            return
        }
        let radius = bounds.width
        let center = CGPoint(x: bounds.width / 2, y: bounds.height / 2)
        let circlePath = UIBezierPath(arcCenter: center, radius: CGFloat(radius / 2), startAngle: CGFloat(0 - Double.pi / 2), endAngle:CGFloat(3 * Double.pi / 2), clockwise: true)

        circleLayer = CAShapeLayer()
        circleLayer.path = circlePath.cgPath
        circleLayer.fillColor = UIColor.clear.cgColor
        circleLayer.strokeColor = UIColor.white.cgColor
        circleLayer.strokeStart = 0.0
        circleLayer.strokeEnd = 1.0 / 12
        circleLayer.lineWidth = 8

        backgroundCircleLayer = CAShapeLayer()
        backgroundCircleLayer.path = circlePath.cgPath
        backgroundCircleLayer.fillColor = UIColor.clear.cgColor
        backgroundCircleLayer.strokeColor = UIColor(red: 1, green: 1, blue: 1, alpha: 0.1).cgColor
        backgroundCircleLayer.strokeStart = 0.0
        backgroundCircleLayer.strokeEnd = 1.0
        backgroundCircleLayer.lineWidth = 8

        layer.addSublayer(backgroundCircleLayer)
        layer.addSublayer(circleLayer)
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
        circleLayer.strokeEnd = destination / 12
        animation.fromValue = origin / 12
        animation.toValue = destination / 12
        animation.timingFunction = CAMediaTimingFunction(name: CAMediaTimingFunctionName.easeInEaseOut)
        animation.isRemovedOnCompletion = false
        circleLayer.add(animation, forKey: "animateCircle")
        CATransaction.commit()
    }

}
