/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import WebKit

class TermsViewController: WebViewController {

    @IBOutlet weak var agreeButton: KeynButton!
    @IBOutlet var gradientView: UIView!

    override func viewDidLoad() {
        let urlPath = Bundle.main.path(forResource: "terms_of_use", ofType: "md")
        url = URL(fileURLWithPath: urlPath!)
        super.viewDidLoad()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        addGradientLayer()
    }

    // MARK: - Actions

    @IBAction func disagree(_ sender: UIButton) {
        let alert = UIAlertController(title: "popups.questions.terms".localized, message: "popups.questions.close_warning".localized, preferredStyle: .alert)
        let cancelAction = UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil)
        alert.addAction(cancelAction)
        alert.addAction(UIAlertAction(title: "initialization.disagree".localized, style: .default, handler: { action in
            self.dismiss(animated: true, completion: nil)
        }))
        self.present(alert, animated: true, completion: nil)
    }


    @IBAction func agree(_ sender: UIButton) {
        let alert = UIAlertController(title: "popups.questions.terms".localized, message: "popups.questions.agree_terms".localized, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "popups.responses.cancel".localized, style: .cancel, handler: nil))
        let agreeAction = UIAlertAction(title: "initialization.agree".localized, style: .default, handler: { action in
            self.performSegue(withIdentifier: "SetupKeyn", sender: self)
        })
        alert.addAction(agreeAction)
        alert.preferredAction = agreeAction
        self.present(alert, animated: true, completion: nil)
    }

    @IBAction func save(_ sender: UIBarButtonItem) {
        let activityViewController = UIActivityViewController(activityItems: [webView.pdf], applicationActivities: nil)
        present(activityViewController, animated: true, completion: nil)
    }


    // MARK: - Private functions

    private func addGradientLayer() {
        let gradientLayer = CAGradientLayer()
        gradientLayer.frame = gradientView.bounds
        var colors = [CGColor]()
        colors.append(UIColor.white.withAlphaComponent(0).cgColor)
        colors.append(UIColor.white.withAlphaComponent(1).cgColor)
        gradientLayer.locations = [NSNumber(value: 0.0),NSNumber(value: 0.4)]
        gradientLayer.colors = colors
        gradientView.layer.insertSublayer(gradientLayer, at: 0)
    }

}
