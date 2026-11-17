import SwiftUI

@main
struct PleiApp: App {
    @StateObject private var store = Store()
    @StateObject private var player = Player()
    @Environment(\.scenePhase) private var phase

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(store)
                .environmentObject(player)
                .environmentObject(player.clock)
                .preferredColorScheme(.dark)
                .onAppear { player.store = store }
                .onOpenURL { url in store.importFiles([url]) }
                .onChange(of: phase) { newPhase in
                    if newPhase == .active { store.importInbox() }
                }
        }
    }
}
