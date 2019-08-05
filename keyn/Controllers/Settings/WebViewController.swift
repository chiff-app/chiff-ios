/*PrivacyViewController
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import WebKit

class WebViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {

    @IBOutlet weak var webView: WKWebView!
    @IBOutlet weak var loadingActivity: UIActivityIndicatorView!

    var url: URL!
    var presentedModally = false

    override func viewDidLoad() {
        super.viewDidLoad()
        if presentedModally {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(cancel))
        }
        webView.uiDelegate = self
        webView.navigationDelegate = self
        let request = URLRequest(url: url)
        webView.load(request)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        loadingActivity.stopAnimating()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        loadingActivity.stopAnimating()
    }

    // MARK: - Navigation

    @objc func cancel() {
        dismiss(animated: true, completion: nil)
    }

}
