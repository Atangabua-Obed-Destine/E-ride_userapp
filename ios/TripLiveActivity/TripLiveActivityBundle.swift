import ActivityKit
import SwiftUI
import WidgetKit

@main
struct TripLiveActivityBundle: WidgetBundle {
    var body: some Widget {
        TripLiveActivityWidget()
    }
}

struct TripLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: TripActivityAttributes.self) { context in
            TripLiveActivityLockScreenView(state: context.state)
                .activityBackgroundTint(.white)
                .activitySystemActionForegroundColor(.black)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    TripAvatarView(urlString: context.state.avatarUrl)
                        .frame(width: 32, height: 32)
                }
                DynamicIslandExpandedRegion(.trailing) {
                    Text("\(context.state.etaText) min")
                        .font(.headline)
                        .foregroundColor(TripBrand.color)
                }
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.title)
                        .font(.caption)
                        .lineLimit(1)
                }
                DynamicIslandExpandedRegion(.bottom) {
                    TripProgressTrack(progress: context.state.progress, vehicleType: context.state.vehicleType, vehicleImageUrl: context.state.vehicleImageUrl)
                        .padding(.top, 4)
                }
            } compactLeading: {
                TripVehicleImage(urlString: context.state.vehicleImageUrl, vehicleType: context.state.vehicleType)
                    .frame(width: 18, height: 18)
            } compactTrailing: {
                Text(context.state.etaText)
                    .font(.caption2)
                    .bold()
            } minimal: {
                TripVehicleImage(urlString: context.state.vehicleImageUrl, vehicleType: context.state.vehicleType)
                    .frame(width: 16, height: 16)
            }
        }
    }
}

enum TripBrand {
    static let color = Color(red: 0 / 255, green: 160 / 255, blue: 141 / 255)

    /// The lock-screen card forces a white background via `activityBackgroundTint(.white)`,
    /// so text must use EXPLICIT dark colours. Relying on the adaptive default
    /// (`.primary` / `.secondary`) makes the text white in dark mode — i.e. invisible
    /// on the white card. Values mirror the Android layout (#1A1A1A / #8A9099).
    static let textPrimary = Color(red: 0x1A / 255, green: 0x1A / 255, blue: 0x1A / 255)
    static let textSecondary = Color(red: 0x8A / 255, green: 0x90 / 255, blue: 0x99 / 255)
}

struct TripLiveActivityLockScreenView: View {
    let state: TripActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12).fill(TripBrand.color)
                    TripLogoImage()
                        .padding(9)
                }
                .frame(width: 46, height: 46)

                VStack(alignment: .leading, spacing: 2) {
                    Text(state.title)
                        .font(.subheadline)
                        .bold()
                        .foregroundColor(TripBrand.textPrimary)
                        .lineLimit(1)
                    Text(state.subtitle)
                        .font(.caption)
                        .foregroundColor(TripBrand.textSecondary)
                        .lineLimit(1)
                }
                Spacer()
            }

            TripProgressTrack(progress: state.progress, vehicleType: state.vehicleType, vehicleImageUrl: state.vehicleImageUrl)

            HStack(spacing: 10) {
                TripAvatarView(urlString: state.avatarUrl)
                    .frame(width: 36, height: 36)

                VStack(alignment: .leading, spacing: 1) {
                    Text(state.driverName)
                        .font(.footnote)
                        .bold()
                        .foregroundColor(TripBrand.textPrimary)
                        .lineLimit(1)
                    Text([state.vehicleModel, state.plateNumber].filter { !$0.isEmpty }.joined(separator: "  •  "))
                        .font(.caption2)
                        .foregroundColor(TripBrand.textSecondary)
                        .lineLimit(1)
                }
                Spacer()

                TripVehicleImage(urlString: state.vehicleImageUrl, vehicleType: state.vehicleType, glyphColor: TripBrand.color)
                    .frame(width: 36, height: 36)
            }
        }
        .padding(14)
    }
}

/// Horizontal dashed track with the vehicle icon slid to `progress` (0...1)
/// along its width — the iOS counterpart of Android's API 31+ precise
/// repositioning (here it's exact, via GeometryReader, on every OS version).
struct TripProgressTrack: View {
    let progress: Double
    let vehicleType: String
    var vehicleImageUrl: String = ""

    var body: some View {
        GeometryReader { proxy in
            let iconSize: CGFloat = 34
            let dotSize: CGFloat = 14
            let W = proxy.size.width
            let midY = proxy.size.height / 2
            let clamped = min(1, max(0, progress))

            let grayColor = Color(red: 0xC7 / 255, green: 0xCC / 255, blue: 0xD1 / 255)
            let dashStyle = StrokeStyle(lineWidth: 2, lineCap: .round, dash: [12, 6])

            // Line spans between the inner edges of the two endpoint dots.
            let lineStartX = dotSize + 4
            let lineEndX = W - dotSize - 4
            let lineWidth = max(0, lineEndX - lineStartX)

            // Icon slides across the full width; completed line runs to its center.
            let trackWidth = max(0, W - iconSize)
            let iconCenterX = trackWidth * clamped + iconSize / 2
            let completedWidth = max(0, min(lineEndX, iconCenterX) - lineStartX)

            ZStack(alignment: .topLeading) {
                // Remaining (gray) dashed line — full span.
                TripDashedLine()
                    .stroke(grayColor, style: dashStyle)
                    .frame(width: lineWidth, height: 2)
                    .position(x: lineStartX + lineWidth / 2, y: midY)

                // Completed (primary/teal) dashed line — overlays the gray up to the icon.
                TripDashedLine()
                    .stroke(TripBrand.color, style: dashStyle)
                    .frame(width: completedWidth, height: 2)
                    .position(x: lineStartX + completedWidth / 2, y: midY)

                TripEndpointDot(color: TripBrand.color)
                    .frame(width: dotSize, height: dotSize)
                    .position(x: dotSize / 2, y: midY)

                TripEndpointDot(color: grayColor,
                                centerColor: Color(red: 0xB0 / 255, green: 0xB6 / 255, blue: 0xBC / 255))
                    .frame(width: dotSize, height: dotSize)
                    .position(x: W - dotSize / 2, y: midY)

                TripVehicleImage(urlString: vehicleImageUrl, vehicleType: vehicleType, glyphColor: TripBrand.color)
                    .frame(width: iconSize, height: iconSize)
                    .position(x: iconCenterX, y: midY)
            }
        }
        .frame(height: 34)
    }
}

/// App notification icon bundled inside the widget extension (notification_icon.png).
/// Falls back to an SF Symbol if the resource can't be loaded.
struct TripLogoImage: View {
    var body: some View {
        if let uiImage = UIImage(named: "notification_icon") {
            Image(uiImage: uiImage)
                .resizable()
                .scaledToFit()
        } else {
            Image(systemName: "app.fill")
                .resizable()
                .scaledToFit()
                .foregroundColor(TripBrand.color)
        }
    }
}

/// A single horizontal line, stroked with a dash pattern by the caller.
struct TripDashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: 0, y: rect.midY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.midY))
        return path
    }
}

/// Concentric endpoint marker: colored ring + white gap + center dot (like the screenshot).
struct TripEndpointDot: View {
    let color: Color
    var centerColor: Color? = nil

    var body: some View {
        ZStack {
            Circle().fill(color)
            Circle().fill(Color.white).padding(3)
            Circle().fill(centerColor ?? color).padding(5)
        }
    }
}

struct TripVehicleIcon: View {
    let vehicleType: String

    var body: some View {
        Image(systemName: vehicleType.lowercased().contains("car") ? "car.fill" : "scooter")
            .resizable()
            .scaledToFit()
    }
}

/// Shows the real vehicle-category image when a URL is provided, otherwise
/// falls back to a white SF Symbol glyph (mirrors the Android bitmap/glyph fallback).
struct TripVehicleImage: View {
    let urlString: String
    let vehicleType: String
    var glyphColor: Color = .white

    var body: some View {
        if let url = URL(string: urlString), !urlString.isEmpty {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFit()
                } else {
                    TripVehicleIcon(vehicleType: vehicleType).foregroundColor(glyphColor)
                }
            }
        } else {
            TripVehicleIcon(vehicleType: vehicleType).foregroundColor(glyphColor)
        }
    }
}

struct TripAvatarView: View {
    let urlString: String

    var body: some View {
        AsyncImage(url: URL(string: urlString)) { phase in
            if case .success(let image) = phase {
                image.resizable().scaledToFill()
            } else {
                RoundedRectangle(cornerRadius: 8).fill(Color.gray.opacity(0.3))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
