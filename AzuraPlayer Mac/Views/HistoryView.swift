import SwiftUI

struct HistoryView: View {
    @ObservedObject private var store = PlaybackHistoryStore.shared
    @AppStorage("appLanguage") private var lang = "en"
    @State private var showClearConfirmation = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text(tr("History", "Verlauf", lang))
                    .font(.headline)
                Spacer()
                if !store.entries.isEmpty {
                    Button(role: .destructive) {
                        showClearConfirmation = true
                    } label: {
                        Label(tr("Clear", "Leeren", lang), systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.borderless)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            if store.entries.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "music.note.list")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text(tr("No entries yet", "Noch keine Einträge", lang))
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(tr(
                        "Songs will appear here once a stream is playing.",
                        "Hier erscheinen Songs, sobald ein Stream läuft.",
                        lang
                    ))
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                }
                .padding()
                Spacer()
            } else {
                ScrollViewReader { proxy in
                    List(store.entries) { entry in
                        HistoryRow(entry: entry)
                            .listRowSeparator(.visible)
                            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                            .id(entry.id)
                    }
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                    .onChange(of: store.entries.first?.id) { _, newID in
                        if let id = newID {
                            withAnimation {
                                proxy.scrollTo(id, anchor: .top)
                            }
                        }
                    }
                }
            }
        }
        .confirmationDialog(
            tr("Clear History?", "Verlauf löschen?", lang),
            isPresented: $showClearConfirmation
        ) {
            Button(tr("Clear All", "Alles löschen", lang), role: .destructive) {
                store.clearAll()
            }
        } message: {
            Text(tr("This cannot be undone.", "Das kann nicht rückgängig gemacht werden.", lang))
        }
    }
}

// MARK: - Row

private struct HistoryRow: View {
    let entry: PlaybackEntry
    @State private var artwork: NSImage? = nil

    private var timeString: String {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: entry.timestamp)
    }

    private var dateString: String {
        let f = DateFormatter()
        f.dateStyle = .short
        f.timeStyle = .none
        let today = Calendar.current.isDateInToday(entry.timestamp)
        return today ? "" : f.string(from: entry.timestamp)
    }

    var body: some View {
        HStack(spacing: 12) {
            // Cover
            ZStack {
                if let img = artwork {
                    Image(nsImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(NSColor.quaternaryLabelColor)
                    Image(systemName: "music.note")
                        .font(.system(size: 14))
                        .foregroundStyle(.tertiary)
                }
            }
            .frame(width: 46, height: 46)
            .clipShape(RoundedRectangle(cornerRadius: 6))
            .task {
                await loadArtwork()
            }

            // Text — auf macOS ist Text in Lists direkt mit Maus selektierbar
            VStack(alignment: .leading, spacing: 2) {
                Group {
                    if entry.artist.isEmpty {
                        Text(entry.songTitle)
                    } else {
                        Text("\(entry.artist) – \(entry.songTitle)")
                    }
                }
                .font(.system(size: 13))
                .lineLimit(1)

                Text(entry.stationName)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            // Zeit
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeString)
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
                if !dateString.isEmpty {
                    Text(dateString)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(.vertical, 2)
        .textSelection(.enabled)
    }

    private func loadArtwork() async {
        guard let urlString = entry.artworkURL,
              let url = URL(string: urlString) else { return }
        guard let (data, _) = try? await URLSession.shared.data(from: url),
              let image = NSImage(data: data) else { return }
        artwork = image
    }
}
