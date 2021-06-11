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

import Foundation
import os
import PromiseKit

class ActiveCaptainAPIClient {
    func getAccessToken(serviceUrl: String, serviceTicket: String) -> Promise<String> {
        var components = URLComponents(string:ActiveCaptainConfiguration.apiBaseURL)!
        components.path += "/api/v1/authentication/access-token"
        components.queryItems = [URLQueryItem(name:"serviceUrl", value:serviceUrl), URLQueryItem(name:"serviceTicket", value:serviceTicket)]

        return sendRequestAndDecode(String.self, .get, components)
    }

    func getExports(tileCoordinates: [TileCoordinate]) -> Promise<[ExportResponse]> {
        var components = URLComponents(string:ActiveCaptainConfiguration.apiBaseURL)!
        components.path += "/api/v2/points-of-interest/export"

        var body: Data?
        do {
            body = try JSONEncoder().encode(tileCoordinates)
        } catch {
            os_log("Failed to encode tileCoordinates to JSON")
        }

        return sendRequestAndDecode([ExportResponse].self, .post, components, "", body)
    }

    func getSyncStatus(databaseVersion: String, syncStatusRequests: [SyncStatusRequest]) -> Promise<[SyncStatusResponse]> {
        var components = URLComponents(string:ActiveCaptainConfiguration.apiBaseURL)!
        components.path += "/api/v2.1/points-of-interest/sync-status"
        components.queryItems = [URLQueryItem(name:"databaseVersion", value:databaseVersion)]

        var body: Data?
        do {
            body = try JSONEncoder().encode(syncStatusRequests)
        } catch {
            os_log("Failed to encode syncStatusRequests to JSON")
        }

        return sendRequestAndDecode([SyncStatusResponse].self, .post, components, "", body)
    }

    func getTiles(boundingBoxes: [BoundingBox]) -> Promise<[TileCoordinate]> {
        var components = URLComponents(string:ActiveCaptainConfiguration.apiBaseURL)!
        components.path += "/api/v2/points-of-interest/tiles"

        var body: Data?
        do {
            body = try JSONEncoder().encode(boundingBoxes)
        } catch {
            os_log("Failed to encode boundingBoxes to JSON")
        }

        return sendRequestAndDecode([TileCoordinate].self, .post, components, "", body)
    }

    func getUser(authHeader: String) -> Promise<UserResponse> {
        var components = URLComponents(string:ActiveCaptainConfiguration.apiBaseURL)!
        components.path += "/api/v1/user"

        return sendRequestAndDecode(UserResponse.self, .get, components, authHeader)
    }

    func refreshToken(authHeader: String) -> Promise<String> {
        var components = URLComponents(string:ActiveCaptainConfiguration.apiBaseURL)!
        components.path += "/api/v2/authentication/refresh-token"

        return sendRequestAndDecode(String.self, .post, components, authHeader)
    }

    func reportMarkerViewed(markerId:Int64) {
        var components = URLComponents(string:ActiveCaptainConfiguration.apiBaseURL)!
        components.path += String(format:"/api/v2/points-of-interest/%lld/view", markerId)

        sendRequest(.post, components)
    }

    func syncMarkers(tileX:Int, tileY:Int, lastModifiedAfter:String?) -> Promise<String> {
        var components = URLComponents(string:ActiveCaptainConfiguration.apiBaseURL)!
        components.path += "/api/v2/points-of-interest/sync"
        var queryItems = [URLQueryItem(name:"tileX", value:String(tileX)), URLQueryItem(name:"tileY", value:String(tileY))]

        if let lastModifiedAfter = lastModifiedAfter {
            queryItems.append(URLQueryItem(name:"lastModifiedAfter", value:lastModifiedAfter))
        }

        components.queryItems = queryItems

        return firstly {
            sendRequest(.get, components)
        }.compactMap {
            String(data:$0.data, encoding:.utf8)
        }
    }

    func syncReviews(tileX:Int, tileY:Int, lastModifiedAfter:String?) -> Promise<String> {
        var components = URLComponents(string:ActiveCaptainConfiguration.apiBaseURL)!
        components.path += "/api/v2/reviews/sync"
        var queryItems = [URLQueryItem(name:"tileX", value:String(tileX)), URLQueryItem(name:"tileY", value:String(tileY))]

        if let lastModifiedAfter = lastModifiedAfter {
            queryItems.append(URLQueryItem(name:"lastModifiedAfter", value:lastModifiedAfter))
        }

        components.queryItems = queryItems

        return firstly {
            sendRequest(.get, components)
        }.compactMap {
            String(data:$0.data, encoding:.utf8)
        }
    }

    func voteForReview(reviewId:Int64, authHeader:String) -> Promise<String> {
        var components = URLComponents(string:ActiveCaptainConfiguration.apiBaseURL)!
        components.path += String(format:"/api/v2/reviews/%lld/votes", reviewId)

        return firstly {
            sendRequest(.post, components, authHeader)
        }.compactMap {
            String(data:$0.data, encoding:.utf8)
        }
    }

    @discardableResult
    private func sendRequest(_ method: URLRequest.HTTPMethod, _ urlComponents: URLComponents, _ authHeader: String = "", _ body: Data? = nil) -> Promise<(data: Data, response: URLResponse)>{
        var request = URLRequest(url:urlComponents.url!)
        request.httpMethod = method.rawValue
        request.addValue(ActiveCaptainConfiguration.apiKey, forHTTPHeaderField: "apikey")
        request.addValue("application/json", forHTTPHeaderField: "Accept")

        if body != nil {
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        if !authHeader.isEmpty {
            request.addValue(authHeader, forHTTPHeaderField: "Authorization")
        }

        return firstly {
            URLSession.shared.dataTask(.promise, with:request).validate()
        }
    }

    private func sendRequestAndDecode<T:Decodable>(_ model:T.Type, _ method: URLRequest.HTTPMethod, _ urlComponents: URLComponents, _ authHeader: String = "", _ body: Data? = nil) -> Promise<T> {
        return firstly {
            sendRequest(method, urlComponents, authHeader, body)
        }.compactMap(on: DispatchQueue.global(qos: .userInitiated)) {
            try JSONDecoder().decode(T.self, from: $0.data)
        }
    }
}
