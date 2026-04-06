import SwiftUI
import WidgetKit

@main
struct AgentPocketWidgetBundle: WidgetBundle {
    var body: some Widget {
        LockScreenWidget()
        AgentLiveActivityWidget()
    }
}
