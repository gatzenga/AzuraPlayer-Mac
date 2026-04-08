//
//  StatusBarController.swift
//  AzuraPlayer Mac
//
//  Created by Vasco Kugler
//

import Cocoa
import Combine

class StatusBarController: NSObject, NSMenuDelegate {
    let menuItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let icon = NSImage(named: "menubaricon") ?? NSImage()
    private let padding: CGFloat = 2

    private var cancellables = Set<AnyCancellable>()

    override init() {
        super.init()

        menuItem.button?.image = icon
        menuItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
        menuItem.button?.target = self
        menuItem.button?.action = #selector(showMenu)
        menuItem.button?.imagePosition = .imageRight

        // Combine subscriptions — bridge from @Published to AppKit
        AudioPlayerService.shared.$isPlaying
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.playerStatusChanged() }
            .store(in: &cancellables)

        AudioPlayerService.shared.$currentStation
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.playerStatusChanged() }
            .store(in: &cancellables)

        MetadataService.shared.$currentTrack
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateItemText() }
            .store(in: &cancellables)

        // Einstellung "Songtitel anzeigen" beobachten
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.updateItemText() }
            .store(in: &cancellables)

        playerStatusChanged()
    }

    @objc func showMenu() {
        menuItem.menu = buildMenu()
        menuItem.button?.performClick(nil)
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        let playItem = PlayMenuItem()
        playItem.isEnabled = true
        menu.addItem(playItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: "Sender", action: nil, keyEquivalent: ""))

        for station in StationStore.shared.stations {
            let item = NSMenuItem(
                title: station.displayName,
                action: #selector(stationClicked(_:)),
                keyEquivalent: ""
            )
            item.target = self
            item.representedObject = station
            menu.addItem(item)
        }

        menu.addItem(NSMenuItem.separator())

        let aboutItem = NSMenuItem(title: "Über AzuraPlayer", action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        menu.addItem(aboutItem)

        let settingsItem = NSMenuItem(title: "Einstellungen…", action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        menu.addItem(NSMenuItem(
            title: "Beenden",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        ))

        menu.delegate = self
        return menu
    }

    @objc func stationClicked(_ sender: NSMenuItem) {
        guard let station = sender.representedObject as? RadioStation else { return }
        AudioPlayerService.shared.play(station: station)
    }

    @objc func showAbout() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        NSApplication.shared.orderFrontStandardAboutPanel(nil)
    }

    @objc func showSettings() {
        SettingsWindowController.show()
    }

    @objc func playerStatusChanged() {
        updateItemText()
    }

    private func updateItemText() {
        guard let button = menuItem.button else { return }

        let player = AudioPlayerService.shared
        let metadata = MetadataService.shared
        let showTitle = UserDefaults.standard.bool(forKey: "showSongTitleInMenuBar")

        var str = ""
        if showTitle, player.isPlaying, let track = metadata.currentTrack, !track.title.isEmpty {
            str = track.artist.isEmpty ? track.title : "\(track.artist) – \(track.title)"
        }

        if str.isEmpty {
            button.attributedTitle = NSAttributedString()
            menuItem.length = 20
            return
        }

        let label = NSMutableAttributedString()
        label.append(NSAttributedString(string: str))
        label.append(NSAttributedString(
            string: " ",
            attributes: [.kern: 16]
        ))

        menuItem.length = NSStatusItem.variableLength
        button.attributedTitle = label
    }

    func menuDidClose(_ menu: NSMenu) {
        menuItem.menu = nil
    }
}
