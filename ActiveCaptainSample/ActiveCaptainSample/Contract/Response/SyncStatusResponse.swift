import Foundation

enum SyncStatusType: String, Codable {
    case export = "Export"
    case sync = "Sync"
    case delete = "Delete"
    case none = "None"
}

struct SyncStatusResponse: Codable {
    var tileX: Int
    var tileY: Int
    var poiUpdateType: SyncStatusType
    var reviewUpdateType: SyncStatusType
}
