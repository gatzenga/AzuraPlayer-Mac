import SwiftUI
import UniformTypeIdentifiers

struct AddEditStationView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("appLanguage") private var lang = "en"
    let store: StationStore
    var editStation: RadioStation? = nil

    @State private var customName = ""
    @State private var streamURL = ""
    @State private var apiURL = ""
    @State private var showSongArt = false
    @State private var autoFillAPI = true
    @State private var customImageData: Data? = nil

    private var isEditing: Bool { editStation != nil }
    private var canSave: Bool { !streamURL.isEmpty && !apiURL.isEmpty }

    var body: some View {
        VStack(spacing: 0) {

            // Header bar
            HStack {
                Button(tr("Cancel", "Abbrechen", lang)) { dismiss() }
                    .keyboardShortcut(.escape)
                Spacer()
                Text(isEditing
                     ? tr("Edit Station", "Sender bearbeiten", lang)
                     : tr("Add Station", "Sender hinzufügen", lang))
                    .font(.headline)
                Spacer()
                Button(isEditing
                       ? tr("Save", "Sichern", lang)
                       : tr("Add", "Hinzufügen", lang)) {
                    save()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!canSave)
                .keyboardShortcut(.return)
            }
            .padding()

            Divider()

            ScrollView {
                VStack(spacing: 12) {

                    // MARK: Stream GroupBox
                    GroupBox(tr("Stream", "Stream", lang)) {
                        VStack(spacing: 8) {
                            HStack {
                                Text("Stream-URL")
                                    .frame(width: 90, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 13))
                                TextField("", text: $streamURL)
                                    .textFieldStyle(.roundedBorder)
                                    .onChange(of: streamURL) { _, new in
                                        if autoFillAPI { deriveAPIURL(from: new) }
                                    }
                            }

                            HStack {
                                Text("API-URL")
                                    .frame(width: 90, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 13))
                                TextField("", text: $apiURL)
                                    .textFieldStyle(.roundedBorder)
                                Toggle("Auto", isOn: $autoFillAPI)
                                    .fixedSize()
                                    .onChange(of: autoFillAPI) { _, enabled in
                                        if enabled { deriveAPIURL(from: streamURL) }
                                    }
                            }

                            HStack {
                                Text(tr("Name", "Name", lang))
                                    .frame(width: 90, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 13))
                                TextField(tr("Optional", "Optional", lang), text: $customName)
                                    .textFieldStyle(.roundedBorder)
                            }
                        }
                        .padding(.top, 4)
                    }

                    // MARK: Cover GroupBox
                    GroupBox(tr("Cover", "Cover", lang)) {
                        VStack(spacing: 8) {
                            HStack {
                                Text(tr("Song Cover", "Song-Cover", lang))
                                    .frame(width: 90, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 13))
                                Toggle("", isOn: $showSongArt)
                                    .labelsHidden()
                                Spacer()
                            }

                            HStack(alignment: .top, spacing: 12) {
                                Text(tr("Image", "Bild", lang))
                                    .frame(width: 90, alignment: .trailing)
                                    .foregroundStyle(.secondary)
                                    .font(.system(size: 13))

                                // Preview
                                Group {
                                    if let data = customImageData, let image = NSImage(data: data) {
                                        Image(nsImage: image)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Color.secondary.opacity(0.15)
                                            .overlay {
                                                Image(systemName: "photo")
                                                    .foregroundStyle(.secondary)
                                            }
                                    }
                                }
                                .frame(width: 48, height: 48)
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 6) {
                                    Button(tr("Choose Image…", "Bild auswählen…", lang)) {
                                        let panel = NSOpenPanel()
                                        panel.allowsMultipleSelection = false
                                        panel.canChooseDirectories = false
                                        panel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff, .heic, .webP]
                                        panel.title = tr("Choose Station Image", "Senderbild auswählen", lang)
                                        if panel.runModal() == .OK, let url = panel.url {
                                            customImageData = try? Data(contentsOf: url)
                                        }
                                    }

                                    if customImageData != nil {
                                        Button(tr("Remove", "Entfernen", lang), role: .destructive) {
                                            customImageData = nil
                                        }
                                        .foregroundStyle(.red)
                                    }
                                }
                                .padding(.top, 4)

                                Spacer()
                            }
                        }
                        .padding(.top, 4)
                    }
                }
                .padding()
            }
        }
        .frame(width: 420, height: 400)
        .onAppear {
            if let station = editStation {
                customName = station.customName ?? ""
                streamURL = station.streamURL
                apiURL = station.apiURL
                showSongArt = station.showSongArt
                autoFillAPI = station.autoFillAPI
                customImageData = station.customImageData
            }
        }
    }

    // MARK: - Helpers

    private func deriveAPIURL(from streamURL: String) {
        guard autoFillAPI, let url = URL(string: streamURL) else { return }
        var components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        if let path = components?.path {
            let parts = path.split(separator: "/")
            if let listenIdx = parts.firstIndex(of: "listen"), parts.count > listenIdx + 1 {
                let shortcode = parts[listenIdx + 1]
                components?.path = "/api/nowplaying/\(shortcode)"
                components?.queryItems = nil
                if let derived = components?.url?.absoluteString {
                    apiURL = derived
                }
            }
        }
    }

    private func save() {
        var station = editStation ?? RadioStation(streamURL: streamURL, apiURL: apiURL)
        station.customName = customName.isEmpty ? nil : customName
        station.streamURL = streamURL
        station.apiURL = apiURL
        station.showSongArt = showSongArt
        station.autoFillAPI = autoFillAPI
        station.customImageData = customImageData

        if isEditing {
            store.update(station: station)
        } else {
            store.add(station: station)
        }
        dismiss()
    }
}
