import AppKit
import SwiftUI

@main
struct ReplayApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = QueueStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .environmentObject(appDelegate.inbox)
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.willTerminateNotification)) { _ in
                    store.flushPendingSaves()
                }
        }
        .windowStyle(.titleBar)
        .windowToolbarStyle(.unified)
        .defaultSize(width: 1320, height: 820)
        .commands {
            CommandGroup(replacing: .newItem) { }
            ReplayCommands(updater: appDelegate.updater, store: store)
        }

        Settings {
            SettingsView()
                .environmentObject(store)
        }
    }
}

private struct ReplayCommands: Commands {
    @ObservedObject var updater: AppUpdater
    @ObservedObject var store: QueueStore

    var body: some Commands {
        CommandGroup(after: .appInfo) {
            Button(updater.menuTitle) {
                updater.performMenuAction()
            }
            .disabled(!updater.menuItemIsEnabled)

            Divider()
            // The browser choice lives in Settings, which opens even when the
            // main window is closed.
            OpenSettingsButton(title: "YouTube Sign-In…")
            Button("Retry Failed Downloads") { store.retryFailedDownloads() }
                .disabled(!store.hasRetryableFailedDownloads)

            Divider()
            Button("Show Downloads Folder") { store.revealMediaFolder() }
            Button("Show Download Logs") { store.revealLogsFolder() }
        }
    }
}

private struct OpenSettingsButton: View {
    let title: String

    var body: some View {
        if #available(macOS 14.0, *) {
            SettingsLink { Text(title) }
        } else {
            Button(title) {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
        }
    }
}
