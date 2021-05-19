import Foundation

struct ExportFile: Codable {
    var fileSize: Int
    var md5Hash: String
    var url: String
}

struct ExportResponse: Codable {
    var tileX: Int
    var tileY: Int
    var zip: ExportFile
    var gzip: ExportFile
}
