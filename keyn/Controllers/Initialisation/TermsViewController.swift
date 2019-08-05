//
//  TermsViewController.swift
//  keyn
//
//  Created by Bas Doorn on 05/08/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit
import WebKit

class TermsViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {

    @IBOutlet var webView: WKWebView!
    @IBOutlet weak var loadingActivity: UIActivityIndicatorView!
    @IBOutlet weak var agreeButton: KeynButton!

    @IBOutlet var gradientView: UIView!

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.uiDelegate = self
        webView.navigationDelegate = self
        let urlPath = Bundle.main.path(forResource: "privacy_policy", ofType: "html")
        let url = URL(fileURLWithPath: urlPath!)
        let request = URLRequest(url: url)
        webView.load(request)
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        addGradientLayer()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingActivity.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingActivity.stopAnimating()
    }

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
