import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var store: StationStore
    @AppStorage("appLanguage") private var lang = "en"

    var body: some View {
        TabView {
            StationsTab()
                .environmentObject(store)
                .tabItem {
                    Label(tr("Stations", "Sender", lang),
                          systemImage: "antenna.radiowaves.left.and.right")
                }

            GeneralTab()
                .tabItem {
                    Label(tr("General", "Allgemein", lang),
                          systemImage: "gearshape")
                }
        }
    }
}

// MARK: - Stations Tab

private struct StationsTab: View {
    @EnvironmentObject var store: StationStore
    @AppStorage("appLanguage") private var lang = "en"
    @State private var selectedID: RadioStation.ID? = nil
    @State private var showAddSheet = false
    @State private var editingStation: RadioStation? = nil
    @State private var stationToDelete: RadioStation? = nil

    private var selectedStation: RadioStation? {
        store.stations.first { $0.id == selectedID }
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selectedID) {
                ForEach(store.stations) { station in
                    StationSettingsRow(station: station)
                        .tag(station.id)
                }
                .onMove { from, to in
                    store.move(from: from, to: to)
                }
            }
            .listStyle(.inset)
            .scrollContentBackground(.hidden)

            Divider()

            HStack(spacing: 0) {
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: 26, height: 22)
                }
                .buttonStyle(.borderless)
                .help(tr("Add Station", "Sender hinzufügen", lang))

                Button {
                    if let station = selectedStation {
                        stationToDelete = station
                    }
                } label: {
                    Image(systemName: "minus")
                        .frame(width: 26, height: 22)
                }
                .buttonStyle(.borderless)
                .disabled(selectedStation == nil)
                .help(tr("Remove Station", "Sender entfernen", lang))

                Divider()
                    .frame(height: 14)
                    .padding(.horizontal, 2)

                if let station = selectedStation {
                    Button(tr("Edit", "Bearbeiten", lang)) {
                        editingStation = station
                    }
                    .buttonStyle(.borderless)
                    .padding(.horizontal, 6)
                }

                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
        }
        .sheet(isPresented: $showAddSheet) {
            AddEditStationView(store: store)
        }
        .sheet(item: $editingStation) { station in
            AddEditStationView(store: store, editStation: station)
        }
        .confirmationDialog(
            tr("Delete Station?", "Sender löschen?", lang),
            isPresented: Binding(
                get: { stationToDelete != nil },
                set: { if !$0 { stationToDelete = nil } }
            ),
            presenting: stationToDelete,
            actions: { station in
                Button(tr("Delete", "Löschen", lang), role: .destructive) {
                    store.delete(station: station)
                    selectedID = nil
                    stationToDelete = nil
                }
            },
            message: { station in
                Text(tr(
                    "Do you really want to remove '\(station.displayName)'?",
                    "Möchtest du '\(station.displayName)' wirklich entfernen?",
                    lang
                ))
            }
        )
    }
}

// MARK: - Station Row

private struct StationSettingsRow: View {
    let station: RadioStation

    var body: some View {
        HStack(spacing: 10) {
            ZStack {
                if let data = station.customImageData, let image = NSImage(data: data) {
                    Image(nsImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Color(NSColor.quaternaryLabelColor)
                    Image(systemName: "radio")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 28, height: 28)
            .clipShape(RoundedRectangle(cornerRadius: 5))

            VStack(alignment: .leading, spacing: 1) {
                Text(station.displayName)
                    .font(.system(size: 13))
                Text(station.streamURL)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - General Tab

private struct GeneralTab: View {
    @AppStorage("showSongTitleInMenuBar") private var showSongTitleInMenuBar = true
    @AppStorage("appLanguage") private var lang = "en"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {

                // Menu Bar section
                PrefsSection(title: tr("Menu Bar", "Menüleiste", lang)) {
                    Toggle(isOn: $showSongTitleInMenuBar) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(tr("Show song title in menu bar",
                                    "Songtitel in der Menüleiste anzeigen", lang))
                            Text(tr(
                                "Shows artist and title next to the icon while a station is playing.",
                                "Zeigt Künstler und Titel neben dem Icon an, während ein Sender läuft.",
                                lang))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // Language section
                PrefsSection(title: "Sprache / Language") {
                    Picker(tr("Language", "Sprache", lang), selection: $lang) {
                        Text("English").tag("en")
                        Text("Deutsch").tag("de")
                    }
                    .pickerStyle(.radioGroup)
                    .labelsHidden()
                }
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Prefs Section Helper

private struct PrefsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
            content()
                .padding(.leading, 4)
        }
    }
}
