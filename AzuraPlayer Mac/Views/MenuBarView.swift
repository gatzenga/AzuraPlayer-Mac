import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var store: StationStore
    @EnvironmentObject var player: AudioPlayerService
    @ObservedObject private var metadata = MetadataService.shared
    @Environment(\.openSettings) private var openSettings
    @AppStorage("appLanguage") private var lang = "en"

    var body: some View {

        // ── Now Playing ─────────────────────────────
        if player.isPlaying, let station = player.currentStation {
            Button {
                player.stop()
            } label: {
                VStack(alignment: .leading, spacing: 2) {
                    if let track = metadata.currentTrack, !track.title.isEmpty {
                        Text(track.artist.isEmpty
                             ? track.title
                             : "\(track.artist) – \(track.title)")
                            .font(.system(size: 13, weight: .semibold))
                    } else {
                        Text(player.isBuffering
                             ? tr("Connecting…", "Verbinde…", lang)
                             : tr("Loading…", "Lädt…", lang))
                            .font(.system(size: 13, weight: .semibold))
                    }

                    HStack(spacing: 4) {
                        Image(systemName: metadata.isOnline ? "wifi" : "wifi.exclamationmark")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(metadata.isOnline ? .green : .orange)
                        Text(station.displayName)
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Divider()
        }

        // ── Stations ────────────────────────────────
        Section(tr("Stations", "Sender", lang)) {
            if store.stations.isEmpty {
                Text(tr("No stations configured", "Keine Sender konfiguriert", lang))
            } else {
                ForEach(store.stations) { station in
                    Button {
                        if player.currentStation?.id == station.id && player.isPlaying {
                            player.stop()
                        } else {
                            player.play(station: station)
                        }
                    } label: {
                        HStack {
                            Text(station.displayName)
                            Spacer()
                            if player.currentStation?.id == station.id && player.isPlaying {
                                Image(systemName: "speaker.wave.2.fill")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
        }

        Divider()

        // ── Actions ─────────────────────────────────
        Button(tr("About AzuraPlayer", "Über AzuraPlayer", lang)) {
            NSApplication.shared.activate(ignoringOtherApps: true)
            NSApplication.shared.orderFrontStandardAboutPanel(nil)
        }

        Button(tr("Settings…", "Einstellungen …", lang)) {
            NSApplication.shared.activate(ignoringOtherApps: true)
            openSettings()
        }
        .keyboardShortcut(",", modifiers: .command)

        Divider()

        Button(tr("Quit", "Beenden", lang)) {
            NSApplication.shared.terminate(nil)
        }
        .keyboardShortcut("q", modifiers: .command)
    }
}
