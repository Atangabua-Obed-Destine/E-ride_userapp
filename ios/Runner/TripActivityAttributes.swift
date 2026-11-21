import ActivityKit
import Foundation

/// Shared between the Runner app target and the TripLiveActivity widget
/// extension target, so both compile against the same ActivityAttributes type.
@available(iOS 16.1, *)
struct TripActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        var title: String
        var subtitle: String
        var etaText: String
        var progress: Double
        var driverName: String
        var vehicleModel: String
        var plateNumber: String
        var vehicleType: String
        var avatarUrl: String
        var vehicleImageUrl: String
    }

    var tripId: String
}
