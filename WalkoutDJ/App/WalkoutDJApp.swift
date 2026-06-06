import SwiftUI

@main
struct WalkoutDJApp: App {
    @StateObject private var storageManager = StorageManager()
    @StateObject private var audioManager = AudioManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(storageManager)
                .environmentObject(audioManager)
        }
    }
}
