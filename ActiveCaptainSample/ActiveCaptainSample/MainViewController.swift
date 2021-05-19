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

class MainViewController: UIViewController, WKUIDelegate, WKNavigationDelegate {
    var webView: WKWebView!
    var markerId:Int64 = 533549  /* Refers to https://activecaptain-stage.garmin.com/pois/533549, a test marker */

    override func loadView() {
        super.loadView()
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.setURLSchemeHandler(AcdbUrlSchemeHandler(), forURLScheme: "acdb")
        webView = WKWebView(frame: self.view.frame, configuration: webConfiguration)
        webView.uiDelegate = self
        webView.navigationDelegate = self
        view = webView

        navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .search, target: self, action: #selector(searchTapped))
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.isNavigationBarHidden = false
        navigationController?.isToolbarHidden = false
        navigationController?.hidesBarsOnSwipe = false

        NotificationCenter.default.addObserver(self, selector: #selector(self.markerSelected(_:)), name: NotifyType.markerSelected.name, object: nil)
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        NotificationCenter.default.removeObserver(self, name: NotifyType.markerSelected.name, object: nil)
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = ActiveCaptainConfiguration.appTitle
        ActiveCaptainManager.instance.database.setImagePrefixWithValue(AcdbUrlSchemeHandler.imagePrefix)

        let scale : String = "1.0"
        let viewportSpecifier = "<meta name=\"viewport\" content=\"initial-scale=\(scale), maximum-scale=\(scale), user-scalable=no\" />"
        let charsetSpecifier = "<meta charset=\"UTF-8\">"
        let stylesheetUrl = Bundle.main.path(forResource: "acdbLight", ofType: "css")
        if let stylesheetUrl = stylesheetUrl {
            do {
                let styleSheet = try String(contentsOfFile: stylesheetUrl, encoding: .utf8)
                let headContent = "\n\(charsetSpecifier)\n\(viewportSpecifier)\n<style>\n\(styleSheet)\n</style>\n"
                ActiveCaptainManager.instance.database.setHeadContentWithValue(headContent)
            } catch {
            }
        }

        let bboxes:[BoundingBox] = [BoundingBox(northeastCorner: Coordinate(latitude: 72.0, longitude: -64.0), southwestCorner: Coordinate(latitude: 17.0, longitude: -171.0))
        ];

        ActiveCaptainManager.instance.set(boundingBoxes: bboxes)

        firstly {
            ActiveCaptainManager.instance.updateData()
        }.done {
            self.reloadContent()
            ActiveCaptainManager.instance.setAutoUpdate(enabled: true)
        }.catch { error in
            os_log("Failed to update data: %s", error.localizedDescription)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        var allow = true

        guard let url = navigationAction.request.url else { decisionHandler(.allow); return }

        if url.scheme == AcdbUrlSchemeHandler.scheme {
            guard let acdbUrlAction = ActiveCaptainManager.instance.database.parseAcdbUrl(withUrl: url.absoluteString, captainName: ActiveCaptainManager.instance.captainName, pageSize: Int32(ActiveCaptainConfiguration.reviewListPageSize)) else { decisionHandler(.allow); return }

            switch acdbUrlAction.action {
            case .edit, .reportReview:
                let editViewContoller = EditViewController()
                editViewContoller.editURLContent = acdbUrlAction.content
                navigationController?.pushViewController(editViewContoller, animated: true)
                allow = false
            case .seeAll, .showPhotos, .showSummary, .voteReview, .unknown:
                break
            @unknown default:
                os_log("Unrecognized ActionType")
            }
        }

        decisionHandler(allow ? .allow : .cancel)
    }

    @objc func markerSelected(_ notification: Notification) {
        guard let markerId = notification.userInfo?[MarkerIdUserInfoKey] as? Int64 else { return }
        self.markerId = markerId
        reloadContent()
    }

    @objc func searchTapped(_ sender:UIBarButtonItem) {
        self.present(UINavigationController(rootViewController: SearchViewController()), animated: true, completion: nil)
    }

    func reloadContent() {
        DispatchQueue.main.async {
            ActiveCaptainManager.instance.reportMarkerViewed(markerId: self.markerId)
            let url = URL(string:String(format:"acdb://summary/%lld", self.markerId))!
            let request = URLRequest(url:url)
            self.webView.load(request)
        }
    }
}

