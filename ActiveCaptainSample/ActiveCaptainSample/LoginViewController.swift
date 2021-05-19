/*------------------------------------------------------------------------------
Copyright 2021 Garmin Ltd. or its subsidiaries.

Licensed under the Apache License, Version 2.0 (the "License");
you may not use this file except in compliance with the License.
You may obtain a copy of the License at

    http://www.apache.org/licenses/LICENSE-2.0

Unless required by applicable law or agreed to in writing, software
distributed under the License is distributed on an "AS IS" BASIS,
WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
See the License for the specific language governing permissions and
limitations under the License.
------------------------------------------------------------------------------*/

import os
import PromiseKit
import UIKit
import WebKit

class LoginViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {
    var webView: WKWebView!

    override func loadView() {
        super.loadView()
        webView = WKWebView(frame: self.view.frame, configuration: WKWebViewConfiguration())
        webView.uiDelegate = self
        webView.navigationDelegate = self
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = ActiveCaptainConfiguration.appTitle

        let url = URL(string:ActiveCaptainConfiguration.ssoURL)!
        let request = URLRequest(url: url)
        webView.load(request)
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        var allow = true

        guard let url = navigationAction.request.url, let host = url.host else { decisionHandler(.allow); return }

        if url.scheme == "https" && host.hasSuffix("garmin.com") {
            guard let query = url.query, let range = query.range(of: "ticket="), let urlIndex = url.absoluteString.firstIndex(of: "?") else { decisionHandler(.allow); return }

            let serviceUrl = String(url.absoluteString[..<urlIndex])
            var serviceTicket: String?

            if range.lowerBound != range.upperBound {
                serviceTicket = String(query[range.upperBound...])
            }

            guard let serviceTicket = serviceTicket else { decisionHandler(.allow); return }

            firstly {
                ActiveCaptainManager.instance.fetchAccessToken(serviceUrl: serviceUrl, serviceTicket: serviceTicket)
            }.done {
                if let navigationController = self.navigationController {
                    var viewControllers = navigationController.viewControllers
                    if let index = viewControllers.firstIndex(of: self) {
                        viewControllers.remove(at: index)
                    }

                    viewControllers.append(UIStoryboard(name:"Main", bundle: Bundle.main).instantiateViewController(withIdentifier:"MainViewController"))
                    navigationController.setViewControllers(viewControllers, animated: true)
                }
            }.catch { error in
                os_log("Failed to fetch access token: %s", error.localizedDescription)
            }

            allow = false
        }

        decisionHandler(allow ? .allow : .cancel)
    }
}
