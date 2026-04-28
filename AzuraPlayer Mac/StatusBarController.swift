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
        let lang = UserDefaults.standard.string(forKey: UserDefaults.Keys.appLanguage) ?? "en"
        let menu = NSMenu()

        let playItem = PlayMenuItem()
        playItem.isEnabled = true
        menu.addItem(playItem)

        menu.addItem(NSMenuItem.separator())

        menu.addItem(NSMenuItem(title: tr("Stations", "Sender", lang), action: nil, keyEquivalent: ""))

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

        let historyItem = NSMenuItem(title: tr("History", "Verlauf", lang), action: #selector(showHistory), keyEquivalent: "")
        historyItem.target = self
        historyItem.image = NSImage(systemSymbolName: "clock.arrow.circlepath", accessibilityDescription: nil)
        menu.addItem(historyItem)

        let settingsItem = NSMenuItem(title: tr("Settings", "Einstellungen", lang), action: #selector(showSettings), keyEquivalent: ",")
        settingsItem.target = self
        settingsItem.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        menu.addItem(settingsItem)

        let aboutItem = NSMenuItem(title: tr("About AzuraPlayer", "Über AzuraPlayer", lang), action: #selector(showAbout), keyEquivalent: "")
        aboutItem.target = self
        aboutItem.image = NSImage(systemSymbolName: "info.circle", accessibilityDescription: nil)
        menu.addItem(aboutItem)

        menu.addItem(NSMenuItem(
            title: tr("Quit", "Beenden", lang),
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

        let credits = NSMutableAttributedString()

        let linkStyle: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.linkColor
        ]
        let labelStyle: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 11),
            .foregroundColor: NSColor.secondaryLabelColor
        ]

        let website = NSMutableAttributedString(string: "Website", attributes: linkStyle)
        website.addAttribute(.link,
            value: URL(string: "https://vkugler.app")!,
            range: NSRange(location: 0, length: website.length))

        let github = NSMutableAttributedString(string: "GitHub", attributes: linkStyle)
        github.addAttribute(.link,
            value: URL(string: "https://github.com/gatzenga/AzuraPlayer-Mac")!,
            range: NSRange(location: 0, length: github.length))

        let separator = NSAttributedString(string: "   ·   ", attributes: labelStyle)

        let privacy = NSMutableAttributedString(string: "Datenschutz", attributes: linkStyle)
        privacy.addAttribute(.link,
            value: URL(string: "https://gatzenga.github.io/AzuraPlayer/privacy.html")!,
            range: NSRange(location: 0, length: privacy.length))

        let contact = NSMutableAttributedString(string: "Kontakt", attributes: linkStyle)
        contact.addAttribute(.link,
            value: URL(string: "mailto:kontakt@vkugler.ch")!,
            range: NSRange(location: 0, length: contact.length))

        credits.append(website)
        credits.append(separator)
        credits.append(github)
        credits.append(separator)
        credits.append(privacy)
        credits.append(separator)
        credits.append(contact)

        NSApplication.shared.orderFrontStandardAboutPanel(options: [
            .credits: credits
        ])
    }

    @objc func showHistory() {
        HistoryWindowController.show()
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
        let showTitle = UserDefaults.standard.bool(forKey: UserDefaults.Keys.showSongTitleInMenuBar)

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
