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

import ActiveCaptainCommunitySDK
import Foundation
import os
import WebKit

class AcdbUrlSchemeHandler: NSObject, WKURLSchemeHandler {
    static let imagePrefix = "acdb://image/"
    static let scheme = "acdb"

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        if let url = urlSchemeTask.request.url, url.scheme == AcdbUrlSchemeHandler.scheme {
            if url.absoluteString.hasPrefix(AcdbUrlSchemeHandler.imagePrefix) {
                guard let data = ActiveCaptainManager.instance.loadImage(url.lastPathComponent) else { return }

                let urlResponse = URLResponse(url:url, mimeType:"image/png", expectedContentLength: -1, textEncodingName: nil)
                urlSchemeTask.didReceive(urlResponse)
                urlSchemeTask.didReceive(data)
                urlSchemeTask.didFinish()
            } else {
                guard let acdbUrlAction = ActiveCaptainManager.instance.database.parseAcdbUrl(withUrl: url.absoluteString, captainName: ActiveCaptainManager.instance.captainName, pageSize: Int32(ActiveCaptainConfiguration.reviewListPageSize)) else { return }

                switch acdbUrlAction.action {
                // Load a webview
                case .edit, .reportReview:
                    break
                // Render content from database
                case .seeAll, .showPhotos, .showSummary:
                    let urlResponse = URLResponse(url:url, mimeType:"text/html", expectedContentLength: -1, textEncodingName: "UTF-8")
                    urlSchemeTask.didReceive(urlResponse)
                    let data = acdbUrlAction.content.data(using: .utf8)
                    if let data = data {
                        urlSchemeTask.didReceive(data)
                        urlSchemeTask.didFinish()
                    }
                // Make an API call
                case .voteReview:
                    let reviewId = Int64(acdbUrlAction.content)
                    if let reviewId = reviewId {
                        ActiveCaptainManager.instance.voteForReview(reviewId: reviewId)
                    }
                case .unknown:
                    os_log("Failed to parse action type from ACDB URL: %s", url.absoluteString)
                @unknown default:
                    os_log("Unknown ACDB URL action type.")
                }
            }
        }
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {

    }
}
