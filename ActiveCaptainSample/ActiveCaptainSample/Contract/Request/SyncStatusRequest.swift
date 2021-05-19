import Foundation

struct SyncStatusRequest: Codable {
    var tileX: Int
    var tileY: Int
    var poiDateLastModified: String?
    var reviewDateLastModified: String?
}
