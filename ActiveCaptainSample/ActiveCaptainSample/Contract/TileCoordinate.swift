import Foundation

struct TileCoordinate: Codable, Hashable {
    var tileX: Int
    var tileY: Int

    public func hash(into hasher: inout Hasher) {
        hasher.combine(tileX)
        hasher.combine(tileY)
    }
}
