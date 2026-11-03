import SwiftUI

/// The Settings window (Replay > Settings…, ⌘,).
///
/// It lives in its own scene, so it opens even when the main window is
/// closed. The YouTube sign-in choice used to be a sheet on the main window,
/// which could not appear without one.
struct SettingsView: View {
    @EnvironmentObject private var store: QueueStore
    @AppStorage(BackgroundPlaybackMode.defaultsKey) private var backgroundPlaybackMode = BackgroundPlaybackMode.miniPlayer.rawValue

    var body: some View {
        Form {
            Section {
                Picker("When Replay is in the background", selection: $backgroundPlaybackMode) {
                    ForEach(BackgroundPlaybackMode.allCases, id: \.rawValue) { mode in
                        Text(mode.menuTitle).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.radioGroup)
                Text("What happens to a playing video when you switch to another app.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } header: {
                Text("Playback")
            }

            Section {
                Picker("Use sign-in from", selection: $store.authenticationBrowser) {
                    ForEach(DownloadBrowser.allCases) { browser in
                        Text(browser == .none ? "Off" : browser.displayName).tag(browser)
                    }
                }
                Text("Some YouTube videos only download when you’re signed in. Replay doesn’t sign in itself: it borrows the YouTube sign-in from a browser where you’re already signed in, using that browser’s default or most recently used profile.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Label {
                    Text("The downloader reads that browser’s cookies on this Mac and sends them only to YouTube. No cookie file is exported.")
                        .fixedSize(horizontal: false, vertical: true)
                } icon: {
                    Image(systemName: "lock.shield")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
                if let note = accessNote {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } header: {
                Text("YouTube Sign-In")
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var accessNote: String? {
        switch store.authenticationBrowser {
        case .none, .firefox:
            return nil
        case .safari:
            return "Safari may require Full Disk Access for Replay in System Settings."
        case .chrome, .edge, .brave:
            return "The first download may ask you to allow access to the browser’s data and its Keychain entry."
        }
    }
}
