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
import PromiseKit

enum NotifyType : String {
    case markerSelected = "markerSelected"
    case markerUpdated = "markerUpdated"

    public var name: Notification.Name {
        return Notification.Name(self.rawValue)
    }
}

let MarkerIdUserInfoKey = "markerId"
let ResourceBundleName = "ActiveCaptainCommunitySDK.bundle"

final class ActiveCaptainManager {
    let jwtKey = "com.garmin.marine.activecaptain.sampleapp.jwt"

    static let instance = ActiveCaptainManager()

    private static let syncMaxResultCount = 100

    private static var basePath: String?

    private(set) var captainName: String?
    private(set) var database: ActiveCaptainDatabase
    private var exportDownloader: ExportDownloader
    private var boundingBoxes: [BoundingBox]

    private var updateTimer: Timer?

    private enum SyncResult {
        case success
        case fail
        case export_required
    }

    class func setup(basePath: String) {
        ActiveCaptainManager.basePath = basePath
    }

    private init() {
        guard let basePath = ActiveCaptainManager.basePath else {
            fatalError("Must call setup() before accessing ActiveCaptainManager.instance")
        }

        let databaseFile = URL(fileURLWithPath: "active_captain.db", relativeTo: URL(fileURLWithPath: basePath))

        database = ActiveCaptainDatabase(path: databaseFile.path, andLanguage: ActiveCaptainConfiguration.languageCode)
        boundingBoxes = []

        exportDownloader = ExportDownloader(database: database, basePath: basePath)

        captainName = nil
        updateTimer = nil
    }

    deinit {
        updateTimer?.invalidate()
    }

    func fetchAccessToken(serviceUrl: String, serviceTicket: String) -> Promise<Void> {
        return firstly {
            ActiveCaptainAPIClient().getAccessToken(serviceUrl: serviceUrl, serviceTicket: serviceTicket)
        }.map { jwt in
            self.set(jwt:jwt)
        }.then {
            ActiveCaptainAPIClient().getUser(authHeader: "Bearer " + self.jwt!)
        }.map { user in
            self.captainName = user.captainName
        }
    }

    func loadImage(_ fileName:String) -> Data? {
        let frameworkBundle = Bundle(for: ActiveCaptainDatabase.self)
        guard let bundleUrl = frameworkBundle.url(forResource: ResourceBundleName, withExtension: nil) else { return nil }
        guard let bundle = Bundle(url:bundleUrl) else { return nil }

        let fileUrl = URL(fileURLWithPath: fileName)
        let baseFileName = fileUrl.deletingPathExtension().lastPathComponent
        let fileExtension = fileUrl.pathExtension

        var scaledFileName = baseFileName
        switch ActiveCaptainConfiguration.imageScale {
        case 3.0...:
            scaledFileName += "@3x"
        case 2.0...:
            scaledFileName += "@2x"
        default:
            break
        }

        var data: Data? = nil

        // Attempt to load the scaled image.
        if let localUrl = bundle.url(forResource:scaledFileName, withExtension: fileExtension) {
            data = try? Data(contentsOf:localUrl)
        }

        // If that didn't work, fall back to the base image.
        if data == nil, let localUrl = bundle.url(forResource:baseFileName, withExtension: fileExtension) {
            data = try? Data(contentsOf:localUrl)
        }

        return data
    }

    var jwt: String? {
        let query = [
            kSecClass as String       : kSecClassGenericPassword,
            kSecAttrAccount as String : jwtKey,
            kSecReturnData as String  : kCFBooleanTrue!,
            kSecMatchLimit as String  : kSecMatchLimitOne ] as [String: Any]

        var dataTypeRef: AnyObject? = nil

        let status: OSStatus = SecItemCopyMatching(query as CFDictionary, &dataTypeRef)
        if status == noErr {
            let data = dataTypeRef as! Data?
            if data != nil {
                let jwt = String(decoding:data!, as: UTF8.self)
                return jwt
            }
        }

        return nil
    }

    func refreshToken() -> Promise<Void> {
        return firstly {
            ActiveCaptainAPIClient().refreshToken(authHeader: "Bearer " + self.jwt!)
        }.map { jwt in
            self.set(jwt: jwt)
        }
    }

    func reportMarkerViewed(markerId: Int64) {
        // If this call fails, we are not required to retry or queue for later.
        ActiveCaptainAPIClient().reportMarkerViewed(markerId: markerId)
    }

    func setAutoUpdate(enabled: Bool) {
        updateTimer?.invalidate()

        if enabled {
            updateTimer = Timer.scheduledTimer(withTimeInterval: Double(ActiveCaptainConfiguration.updateIntervalMins) * 60.0, repeats: true) { timer in
                firstly {
                    self.updateData()
                }.catch { error in
                    os_log("Failed to auto-update: %s", error.localizedDescription)
                }
            }
        } else {
            updateTimer = nil
        }
    }

    func set(boundingBoxes: [BoundingBox]) {
        self.boundingBoxes = boundingBoxes
    }

    func set(jwt: String) {
        if jwt.isEmpty {
            return
        }

        let query = [
            kSecClass as String       : kSecClassGenericPassword as String,
            kSecAttrAccount as String : jwtKey,
            kSecValueData as String   : jwt.data(using: String.Encoding.utf8)! ] as [String: Any]

        SecItemDelete(query as CFDictionary)

        let status: OSStatus = SecItemAdd(query as CFDictionary, nil)
        if status != noErr {
            os_log("Failed to store access token in keychain: status %i", status)
        }
    }

    func updateData() -> Promise<Void> {
        os_log("Update data!")

        if boundingBoxes.isEmpty {
            return Promise.value(())
        }

        var exportTileList = Set<TileCoordinate>()
        var syncPromises = [Promise<Void>]()

        return firstly { () -> Promise<[SyncStatusRequest]> in
            return fetchSyncStatusRequests()
        }.then { (syncStatusRequests: [SyncStatusRequest]) -> Promise<[SyncStatusResponse]> in
            return ActiveCaptainAPIClient().getSyncStatus(databaseVersion: self.database.getVersion(), syncStatusRequests: syncStatusRequests)
        }.then { (syncStatusResponses: [SyncStatusResponse]) -> Promise<Void> in
            syncStatusResponses.forEach{ syncStatusResponse in
                let tileCoordinate = TileCoordinate(tileX: syncStatusResponse.tileX, tileY: syncStatusResponse.tileY)

                switch syncStatusResponse.poiUpdateType {
                case .sync:
                    let promise = self.syncTileMarkers(tileCoordinate: tileCoordinate).done { syncResult in
                        if syncResult == SyncResult.export_required {
                            exportTileList.update(with: tileCoordinate)
                        }
                    }
                    syncPromises.append(promise)
                case .export:
                    exportTileList.insert(tileCoordinate)
                case .delete:
                    self.database.deleteTile(withTileX: Int32(tileCoordinate.tileX), tileY:Int32(tileCoordinate.tileY))
                case .none:
                    break
                }

                switch syncStatusResponse.reviewUpdateType {
                case .sync:
                    let promise = self.syncTileReviews(tileCoordinate: tileCoordinate).done { syncResult in
                        if syncResult == SyncResult.export_required {
                            exportTileList.update(with: tileCoordinate)
                        }
                    }
                    syncPromises.append(promise)
                case .export:
                    exportTileList.insert(tileCoordinate)
                case .delete:
                    self.database.deleteTileReviews(withTileX: Int32(tileCoordinate.tileX), tileY:Int32(tileCoordinate.tileY))
                case .none:
                    break
                }
            }

            return when(fulfilled: syncPromises).then { () -> Promise<Void> in
                if !exportTileList.isEmpty {
                    return firstly {
                        self.exportTiles(tileCoordinates: exportTileList)
                    }.done {
                        // Reinitialize translations, as they may have been updated.
                        self.database.setLanguageWithValue(ActiveCaptainConfiguration.languageCode)
                        os_log("Update complete, exports installed.")
                    }
                } else {
                    os_log("Update complete, no exports.")
                    return Promise.value(())
                }
            }
        }
    }

    func voteForReview(reviewId:Int64) {
        guard let jwt = jwt else { return }

        firstly {
            ActiveCaptainAPIClient().voteForReview(reviewId: reviewId, authHeader: "Bearer " + jwt)
        }.compactMap {
            self.database.processVoteForReviewResponse(withJson: $0)
        }.done {
            NotificationCenter.default.post(name: NotifyType.markerUpdated.name, object:nil)
        }.catch { error in
        }
    }

    private func exportTiles(tileCoordinates:Set<TileCoordinate>) -> Promise<Void> {
        let tileRequests = [TileCoordinate](tileCoordinates)

        return firstly {
            ActiveCaptainAPIClient().getExports(tileCoordinates: tileRequests)
        }.then {
            when(fulfilled: self.exportDownloader.download(exports: $0))
        }
    }

    private func fetchSyncStatusRequests() -> Promise<[SyncStatusRequest]> {
        var lastUpdateInfos = [TileCoordinate: LastUpdateInfoType]()

        boundingBoxes.forEach { bbox in
            let tiles = database.getTilesLastModifiedByBoundingBox(withSouth: bbox.southwestCorner.latitude, west: bbox.southwestCorner.longitude, north: bbox.northeastCorner.latitude, east: bbox.northeastCorner.longitude)

            if let tiles = tiles {
                let keys = tiles.keys
                keys.forEach{ key in
                    var tileXY = TileXY()
                    (key as! NSValue).getValue(&tileXY)

                    let lastUpdateInfo = (tiles[key] as! LastUpdateInfoType)
                    let tileCoordinate = TileCoordinate(tileX: Int(tileXY.tileX), tileY: Int(tileXY.tileY))
                    lastUpdateInfos.updateValue(lastUpdateInfo, forKey: tileCoordinate)
                }
            }
        }

        var syncStatusRequests = [SyncStatusRequest]()
        var promise: Promise<[SyncStatusRequest]>

        if lastUpdateInfos.isEmpty {
            promise = firstly {
                ActiveCaptainAPIClient().getTiles(boundingBoxes: boundingBoxes)
            }.map { tileResponses in
                tileResponses.forEach{ tileResponse in
                    syncStatusRequests.append(SyncStatusRequest(tileX: tileResponse.tileX, tileY: tileResponse.tileY, poiDateLastModified: nil, reviewDateLastModified: nil))
                }

                return syncStatusRequests
            }
        } else {
            lastUpdateInfos.forEach{ lastUpdateInfo in
                syncStatusRequests.append(SyncStatusRequest(tileX: lastUpdateInfo.key.tileX, tileY: lastUpdateInfo.key.tileY, poiDateLastModified: lastUpdateInfo.value.markerLastUpdate, reviewDateLastModified: lastUpdateInfo.value.reviewLastUpdate))
            }

            return Promise.value(syncStatusRequests)
        }

        return promise
    }

    private func syncTileMarkers(tileCoordinate:TileCoordinate, lastModifiedAfter: String? = nil) -> Promise<SyncResult> {
        var lastModifiedAfter = lastModifiedAfter
        if lastModifiedAfter == nil {
            lastModifiedAfter = database.getTileLastModified(withTileX: Int32(tileCoordinate.tileX), tileY: Int32(tileCoordinate.tileY))?.markerLastUpdate

            if lastModifiedAfter == nil {
                return Promise.value(SyncResult.fail)
            }
        }

        return firstly {
            ActiveCaptainAPIClient().syncMarkers(tileX: tileCoordinate.tileX, tileY: tileCoordinate.tileY, lastModifiedAfter: lastModifiedAfter!)
        }.then { (syncResponse: String) -> Promise<SyncResult> in
            let resultCount = Int(self.database.processSyncMarkersResponse(withJson: syncResponse, tileX: Int32(tileCoordinate.tileX), tileY: Int32(tileCoordinate.tileY)))

            if resultCount == ActiveCaptainManager.syncMaxResultCount {
                // Sanity check -- don't call with the same lastModifiedAfter multiple times.  The API would return the same results.
                let nextLastModifiedAfter = self.database.getTileLastModified(withTileX: Int32(tileCoordinate.tileX), tileY: Int32(tileCoordinate.tileY))?.markerLastUpdate

                if nextLastModifiedAfter != lastModifiedAfter {
                    return self.syncTileMarkers(tileCoordinate: tileCoordinate, lastModifiedAfter: nextLastModifiedAfter)
                }
            }

            return Promise.value(SyncResult.success)
        }.recover { error -> Promise<SyncResult> in
            switch error
            {
            case PMKHTTPError.badStatusCode(let code, _, _):
                if code == 303 {
                    return Promise.value(SyncResult.export_required)
                }

            default:
                break
            }

            return Promise.value(SyncResult.fail)
        }
    }

    private func syncTileReviews(tileCoordinate:TileCoordinate, lastModifiedAfter: String? = nil) -> Promise<SyncResult> {
        var lastModifiedAfter = lastModifiedAfter
        if lastModifiedAfter == nil {
            lastModifiedAfter = database.getTileLastModified(withTileX: Int32(tileCoordinate.tileX), tileY: Int32(tileCoordinate.tileY))?.reviewLastUpdate

            if lastModifiedAfter == nil {
                return Promise.value(SyncResult.fail)
            }
        }

        return firstly {
            ActiveCaptainAPIClient().syncReviews(tileX: tileCoordinate.tileX, tileY: tileCoordinate.tileY, lastModifiedAfter: lastModifiedAfter!)
        }.then { (syncResponse: String) -> Promise<SyncResult> in
            let resultCount = Int(self.database.processSyncReviewsResponse(withJson: syncResponse, tileX: Int32(tileCoordinate.tileX), tileY: Int32(tileCoordinate.tileY)))

            if resultCount == ActiveCaptainManager.syncMaxResultCount {
                // Sanity check -- don't call with the same lastModifiedAfter multiple times.  The API would return the same results.
                let nextLastModifiedAfter = self.database.getTileLastModified(withTileX: Int32(tileCoordinate.tileX), tileY: Int32(tileCoordinate.tileY))?.reviewLastUpdate

                if nextLastModifiedAfter != lastModifiedAfter {
                    return self.syncTileReviews(tileCoordinate: tileCoordinate, lastModifiedAfter: nextLastModifiedAfter)
                }
            }

            return Promise.value(SyncResult.success)
        }.recover { error -> Promise<SyncResult> in
            switch error
            {
            case PMKHTTPError.badStatusCode(let code, _, _):
                if code == 303 {
                    return Promise.value(SyncResult.export_required)
                }

            default:
                break
            }

            return Promise.value(SyncResult.fail)
        }
    }
}
