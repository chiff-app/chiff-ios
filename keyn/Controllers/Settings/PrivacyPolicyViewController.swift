/*
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import WebKit

class PrivacyPolicyViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {

    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var loadingActivity: UIActivityIndicatorView!

    override func viewDidLoad() {
        super.viewDidLoad()
        webView.uiDelegate = self
        webView.navigationDelegate = self
        let myURL = URL(string:"https://keyn.app/privacy_raw")
        let myRequest = URLRequest(url: myURL!)
        webView.load(myRequest)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingActivity.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingActivity.stopAnimating()
    }

}
