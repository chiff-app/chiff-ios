/*PrivacyViewController
 * Copyright © 2019 Keyn B.V.
 * All rights reserved.
 */
import UIKit
import WebKit
import Down

class WebViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {

    @IBOutlet weak var containerView: UIView!
    @IBOutlet weak var loadingActivity: UIActivityIndicatorView!
    var webView: WKWebView!

    var url: URL!
    var presentedModally = false

    override func viewDidLoad() {
        super.viewDidLoad()
        if presentedModally {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.done, target: self, action: #selector(cancel))
        }

        if url.pathExtension.lowercased() == "markdown" || url.pathExtension.lowercased() == "md" {
            do {
                let bundleUrl = Bundle.main.path(forResource: "WebView", ofType: "bundle")
                webView = try DownView(frame: containerView.frame, markdownString: String(contentsOf: url, encoding: .utf8), templateBundle: Bundle(url: URL(fileURLWithPath: bundleUrl!))) {
                    self.loadingActivity.stopAnimating()
                }
            } catch {
                loadingActivity.stopAnimating()
                Logger.shared.error("Error paring markdown")
                showError(message: "Error parsing data")
            }
        } else {
            webView = WKWebView(frame: containerView.frame)
            webView.uiDelegate = self
            webView.navigationDelegate = self
            let request = URLRequest(url: url)
            webView.load(request)
        }
        webView.translatesAutoresizingMaskIntoConstraints = false
        containerView.translatesAutoresizingMaskIntoConstraints = false
        containerView.addSubview(webView)

        webView.topAnchor.constraint(equalTo: containerView.topAnchor).isActive = true
        webView.bottomAnchor.constraint(equalTo: containerView.bottomAnchor).isActive = true
        webView.leadingAnchor.constraint(equalTo: containerView.leadingAnchor).isActive = true
        webView.trailingAnchor.constraint(equalTo: containerView.trailingAnchor).isActive = true
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
