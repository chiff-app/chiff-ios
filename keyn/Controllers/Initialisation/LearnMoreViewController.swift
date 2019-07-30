//
//  LearnMoreViewController.swift
//  keyn
//
//  Created by Bas Doorn on 11/04/2019.
//  Copyright © 2019 keyn. All rights reserved.
//

import UIKit
import WebKit

class LearnMoreViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {

    @IBOutlet var webView: WKWebView!
    @IBOutlet weak var loadingActivity: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.uiDelegate = self
        webView.navigationDelegate = self
        let myURL = URL(string:"https://keyn.app/faq_raw")
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)
        Logger.shared.analytics(.learnMoreClicked)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingActivity.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingActivity.stopAnimating()
    }

}
