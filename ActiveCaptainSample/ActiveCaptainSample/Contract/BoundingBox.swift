import Foundation

struct Coordinate: Codable {
    var latitude: Double
    var longitude: Double
}

struct BoundingBox: Codable {
    var northeastCorner: Coordinate
    var southwestCorner: Coordinate
}
