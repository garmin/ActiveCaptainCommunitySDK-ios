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
import UIKit
import WebKit

class EditViewController : UIViewController, WKScriptMessageHandler {
    private struct WebViewEvent {
        var applyResponse: Bool;
        var dismissView: Bool;
    }

    enum MessageType: String, CaseIterable {
        case actionComplete = "actionComplete"
        case success = "SUCCESS"
        case error = "ERROR"
        case delete = "DELETE"
        case reviewDelete = "REVIEWDELETE"
        case reviewFlagged = "REVIEWFLAGGED"
        case reviewSuccess = "REVIEWSUCCESS"
        case editProfile = "EDITPROFILE"
        case emailPreferencesSaved = "EMAILPREFERENCESSUCCESS"

        var triggersDismissal: Bool {
            switch self {
            case .delete, .error, .reviewDelete, .reviewFlagged, .reviewSuccess, .success:
                return true
            case .actionComplete, .editProfile, .emailPreferencesSaved:
                return false
            }
        }

        var applyResponse: Bool {
            switch self {
            case .delete, .reviewDelete, .reviewFlagged, .reviewSuccess, .success:
                return true
            case .actionComplete, .editProfile, .error, .emailPreferencesSaved:
                return false
            }
        }
    }

    var webView: WKWebView!
    var editURLContent: String?

    override func loadView() {
        super.loadView()

        let webConfiguration = WKWebViewConfiguration()
        if #available(iOS 14.0, *) {
            webConfiguration.defaultWebpagePreferences.allowsContentJavaScript = true
        } else {
            webConfiguration.preferences.javaScriptEnabled = true
        }

        for messageType in MessageType.allCases {
            webConfiguration.userContentController.add(self, name:messageType.rawValue)
        }

        webView = WKWebView(frame: self.view.frame, configuration: webConfiguration)
        view = webView
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = ActiveCaptainConfiguration.appTitle

        let request: URLRequest? = fetchURLRequest()
        if let request = request {
            webView.load(request)
        }
    }

    func fetchURLRequest() -> URLRequest? {
        guard let jwt = ActiveCaptainManager.instance.jwt, let editURLContent = editURLContent else { return nil }

        var urlComponents = URLComponents(string:ActiveCaptainConfiguration.webviewBaseUrl)!
        urlComponents.path += "/" + editURLContent
        var query = "version=v2.1&locale=" + ActiveCaptainConfiguration.languageCode
        if ActiveCaptainConfiguration.webviewDebug {
            query += "&debug=true"
        }
        urlComponents.query = query

        var request = URLRequest(url:urlComponents.url!)
        request.setValue("Bearer " + jwt, forHTTPHeaderField: "Authorization")
        request.setValue(ActiveCaptainConfiguration.apiKey, forHTTPHeaderField: "apikey")

        return request
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let messageBody = message.body as? [String:Any] else { return }

        let jwt = messageBody["jwt"] as? String
        if let jwt = jwt, !jwt.isEmpty {
            ActiveCaptainManager.instance.set(jwt: jwt)
        }

        var dismissView = false

        let resultType = messageBody["resultType"] as? String
        if let resultType = resultType, let messageType = MessageType(rawValue: resultType) {
            if messageType.applyResponse {
                do {
                    let content = try JSONSerialization.data(withJSONObject: messageBody)
                    ActiveCaptainManager.instance.database.processWebViewResponse(withJson: String(data: content, encoding: String.Encoding.utf8))
                } catch {
                    os_log("Failed to convert message body to JSON string")
                    dismissView = true
                }
            }

            dismissView = messageType.triggersDismissal
        } else {
            dismissView = true
        }

        if dismissView {
            self.navigationController?.popViewController(animated: true)
        }
    }
}
