import SwiftUI

struct ContentView: View {
    @State private var engine = DebateEngine()

    var body: some View {
        Group {
            if engine.state == .idle {
                SetupView(engine: engine)
            } else {
                DebateView(engine: engine)
            }
        }
        .frame(minWidth: 900, minHeight: 650)
    }
}
