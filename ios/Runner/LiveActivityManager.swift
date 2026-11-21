import ActivityKit
import Flutter
import Foundation

/// iOS side of the live trip progress notification. Mirrors
/// LiveTripNotificationHelper (Dart) / LiveTripNotificationManager (Android):
/// renders the ride/parcel's live pickup/destination progress as a Live
/// Activity (Lock Screen + Dynamic Island) instead of a plain notification.
/// Requires iOS 16.2+: `ActivityContent`, `request(attributes:content:pushType:)`,
/// `update(_:)` and `end(_:dismissalPolicy:)` were all introduced in 16.2.
@available(iOS 16.2, *)
final class LiveActivityManager {
    static let shared = LiveActivityManager()

    private var currentActivity: Activity<TripActivityAttributes>?

    func register(with messenger: FlutterBinaryMessenger) {
        let channel = FlutterMethodChannel(name: "com.i_nnova.eride/live_trip_notification", binaryMessenger: messenger)
        channel.setMethodCallHandler { [weak self] call, result in
            guard let self = self else {
                result(nil)
                return
            }
            switch call.method {
            case "showOrUpdate":
                if let data = call.arguments as? [String: Any] {
                    self.showOrUpdate(data: data)
                }
                result(nil)
            case "stop":
                self.stop()
                result(nil)
            default:
                result(FlutterMethodNotImplemented)
            }
        }
    }

    private func contentState(from data: [String: Any]) -> TripActivityAttributes.ContentState {
        let progress = (data["progress"] as? Double) ?? ((data["progress"] as? NSNumber)?.doubleValue ?? 0)
        return TripActivityAttributes.ContentState(
            title: data["title"] as? String ?? "",
            subtitle: data["subtitle"] as? String ?? "",
            etaText: data["etaText"] as? String ?? "",
            progress: progress,
            driverName: data["driverName"] as? String ?? "",
            vehicleModel: data["vehicleModel"] as? String ?? "",
            plateNumber: data["plateNumber"] as? String ?? "",
            vehicleType: data["vehicleType"] as? String ?? "",
            avatarUrl: data["avatarUrl"] as? String ?? "",
            vehicleImageUrl: data["vehicleImageUrl"] as? String ?? ""
        )
    }

    func showOrUpdate(data: [String: Any]) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        let tripId = data["tripId"] as? String ?? ""
        let state = contentState(from: data)
        let content = ActivityContent(state: state, staleDate: nil)

        if let activity = currentActivity, activity.attributes.tripId == tripId {
            Task { await activity.update(content) }
            return
        }

        if let activity = currentActivity {
            Task { await activity.end(nil, dismissalPolicy: .immediate) }
            currentActivity = nil
        }

        do {
            currentActivity = try Activity<TripActivityAttributes>.request(
                attributes: TripActivityAttributes(tripId: tripId),
                content: content
            )
        } catch {
            print("LiveActivityManager: failed to start Live Activity: \(error)")
        }
    }

    func stop() {
        guard let activity = currentActivity else { return }
        Task { await activity.end(nil, dismissalPolicy: .immediate) }
        currentActivity = nil
    }
}

/// Objective-C-visible entry point so AppDelegate can register the channel
/// without needing `if #available` boilerplate at every call site.
@objc final class LiveActivityBridge: NSObject {
    @objc static func register(with messenger: FlutterBinaryMessenger) {
        if #available(iOS 16.2, *) {
            LiveActivityManager.shared.register(with: messenger)
        }
    }
}
