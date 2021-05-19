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
import CommonCrypto
import Foundation
import Gzip
import os
import PromiseKit

extension Data {
    var md5Hash : String {
        let hash = self.withUnsafeBytes { (bytes: UnsafeRawBufferPointer) -> [UInt8] in
            var hash = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
            CC_MD5(bytes.baseAddress, CC_LONG(self.count), &hash)
            return hash
        }
        return hash.map { String(format: "%02x", $0) }.joined()
    }
}

final class ExportDownloader {
    private var baseFileURL: URL
    private var database: ActiveCaptainDatabase

    init(database:ActiveCaptainDatabase, basePath:String) {
        self.database = database
        self.baseFileURL = URL(fileURLWithPath: basePath)
    }

    func download(exports:[ExportResponse]) -> [Promise<Void>] {
        var promises = [Promise<Void>]()

        exports.forEach { export in
            let targetUrl = URL(fileURLWithPath: String(format:"active_captain_%i_%i", export.tileX, export.tileY), relativeTo: baseFileURL).appendingPathExtension("db")

            var request = URLRequest(url:URL(string: export.gzip.url)!)
            request.httpMethod = URLRequest.HTTPMethod.get.rawValue

            os_log("Downloading %s", export.gzip.url)

            let promise = firstly {
                URLSession.shared.dataTask(.promise, with:request)
            }.done {
                let (data, _) = $0
                let fileSize = (data as NSData).length
                if (export.gzip.fileSize != fileSize) {
                    os_log("File size mismatch: %i %i, Expected: %i, Actual: %i", export.tileX, export.tileY, export.gzip.fileSize, fileSize)
                }
                else if (export.gzip.md5Hash != data.md5Hash) {
                    os_log("MD5 hash mismatch: %i %i, Expected: %s, Actual: %s", export.tileX, export.tileY, export.gzip.md5Hash, data.md5Hash)
                } else {
                    do {
                        let decompressedData = try data.gunzipped()
                        try decompressedData.write(to: targetUrl)
                    } catch {
                        os_log("Failed to write decompressed file: %s", error.localizedDescription)
                    }

                    os_log("Installing: %i %i %s", export.tileX, export.tileY, targetUrl.path)
                    self.database.installTile(withPath: targetUrl.path, tileX: Int32(export.tileX), tileY: Int32(export.tileY))
                }
            }

            promises.append(promise)
        }

        return promises
    }
}
