import SwiftUI
import WidgetKit

// MARK: - Lock Screen Widget

struct LockScreenWidget: Widget {
    let kind = "LockScreenWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: LockScreenProvider()) { _ in
            LockScreenWidgetView()
        }
        .configurationDisplayName("Agent")
        .description("Quick access to voice recording")
        .supportedFamilies([.accessoryCircular])
    }
}

// MARK: - Provider

struct LockScreenProvider: TimelineProvider {
    func placeholder(in context: Context) -> LockScreenEntry {
        LockScreenEntry(date: .now)
    }

    func getSnapshot(in context: Context, completion: @escaping (LockScreenEntry) -> Void) {
        completion(LockScreenEntry(date: .now))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<LockScreenEntry>) -> Void) {
        let entry = LockScreenEntry(date: .now)
        let timeline = Timeline(entries: [entry], policy: .never)
        completion(timeline)
    }
}

// MARK: - Entry

struct LockScreenEntry: TimelineEntry {
    let date: Date
}

// MARK: - View

struct LockScreenWidgetView: View {
    var body: some View {
        ZStack {
            AccessoryWidgetBackground()

            Image(systemName: "mic.circle.fill")
                .font(.system(size: 24, weight: .medium))
                .foregroundStyle(.white)
        }
        .widgetURL(URL(string: SharedConstants.recordURLString))
    }
}
