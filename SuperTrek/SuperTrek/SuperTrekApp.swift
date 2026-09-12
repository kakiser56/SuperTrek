import SwiftUI

@main
struct SuperTrekApp: App {
    @State private var store = GameStore()
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .background || phase == .inactive {
                store.save()
            }
        }
    }
}

struct ContentView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        if store.game == nil {
            NewGameView()
        } else {
            BridgeView()
        }
    }
}
